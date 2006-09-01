<cfcomponent name="ehBlog" extends="coldbox.system.eventhandler">

	<!--- ************************************************************* --->
	<cffunction name="init" access="public" returntype="Any" output="false">
		<cfset super.init()>
		<cfreturn this>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="onAppStart" access="public" returntype="void" output="false">
		<cfset var blogname = getToken(application.applicationName,3,"_")>
		<cfset var lylaFile = "">
		<cfset var majorVersion = "">
		<cfset var minorVersion = "">
		<cfset var cfversion = "">

		<!--- load an init blog --->
		<cfset application.blog = createObject("component","org.camden.blog.blog").init(blogname)>
		<!--- Path may be different if admin. --->
		<cfif findNoCase("admin/", cgi.script_name)>
			<cfset theFile = expandPath("../includes/main")>
			<cfset lylaFile = "../includes/captcha.xml">
		<cfelse>
			<cfset theFile = expandPath("./includes/main")>
			<cfset lylaFile = "./includes/captcha.xml">
		</cfif>
		<cfset application.localeutils = getPlugin("i18n").setfwLocale(getSetting("DefaultLocale"))>

		<!--- Use Captcha? --->
		<cfset application.usecaptcha = application.blog.getProperty("usecaptcha")>

		<cfif application.usecaptcha>
			<cfset application.captcha = CreateObject("component","org.captcha.captchaService").init(configFile="#lylaFile#") />
			<cfset application.captcha.setup() />
		</cfif>

		<!--- clear cache
		<cfmodule template="../tags/scopecache.cfm" scope="application" clearall="true">--->

		<cfset majorVersion = listFirst(server.coldfusion.productversion)>
		<cfset minorVersion = listGetAt(server.coldfusion.productversion,2)>
		<cfset cfversion = majorVersion & "." & minorVersion>

		<cfset application.isColdFusionMX7 = server.coldfusion.productname is "ColdFusion Server" and cfversion gte 7>

		<!--- Used in various places --->
		<cfset application.rootURL = application.blog.getProperty("blogURL")>
		<!--- per documentation - rooturl should be http://www.foo.com/something/something/index.cfm --->
		<cfset application.rootURL = reReplace(application.rootURL, "(.*)/index.cfm", "\1")>

		<!--- used for cache purposes is 60 minutes --->
		<cfset application.timeout = 60*60>

		<!--- how many entries? --->
		<cfset application.maxEntries = application.blog.getProperty("maxentries")>

		<!--- TBs allowed? --->
		<cfset application.trackbacksAllowed = application.blog.getProperty("allowtrackbacks")>

		<!--- We are initialized --->
		<cfset application.init = true>

	</cffunction>
	<!--- ************************************************************* --->
	
	<!--- ************************************************************* --->
	<cffunction name="onRequestStart" access="public" returntype="void" output="false">
		<!--- Encoding --->
		<cfset setEncoding("form","utf-8")>
		<cfset setEncoding("url","utf-8")>

		<cflogin>
			<cfif valueExists("username") and valueExists("password") and len(trim(getValue("username"))) and len(trim(getValue("password")))>
				<cfif application.blog.authenticate(left(trim(getValue("username")),50),left(trim(getValue("password")),50))>
					<cfloginuser name="#trim(getValue("username"))#" password="#trim(getValue("password"))#" roles="admin">
					<!---
						  This was added because CF's built in security system has no way to determine if a user is logged on.
						  In the past, I used getAuthUser(), it would return the username if you were logged in, but
						  it also returns a value if you were authenticated at a web server level. (cgi.remote_user)
						  Therefore, the only say way to check for a user logon is with a flag.
					--->
					<cfset session.loggedin = true>
				</cfif>
			</cfif>
		</cflogin>

		<cfif findNoCase("/admin", cgi.script_name) and not isLoggedIn() and not findNoCase("/admin/index.cfm?event=ehAdmin.dspNotify", cgi.script_name)>
			<cfset overrideEvent("ehAdmin.dspLogin")>
		</cfif>
		
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehEntries = "ehAdmin.dspEntries">
		<cfset rc.xehCategories = "ehAdmin.dspCategories">
		<cfset rc.xehComments = "ehAdmin.dspComments">
		<cfset rc.xehSettings = "ehAdmin.dspSettings">
		<cfset rc.xehSubscribers = "ehAdmin.dspSubscribers">
		<cfset rc.xehTrackbacks = "ehAdmin.dspTrackbacks">
		<cfset rc.xehStats = "ehAdmin.dspStats">
		<cfset rc.xehLogout = "ehAdmin.doLogout">		
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doLogout" access="public" returntype="void" output="false">
		<cfif isLoggedIn()>
			<cfset structDelete(session,"loggedin")>
			<cflogout>
		</cfif>
		<!--- Set the next Event --->
		<cfset setNextEvent("ehAdmin.dspLogin")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspLogin" access="public" returntype="void" output="false">
		<cfset var qs = cgi.query_string>
		<cfset setvalue("qs",reReplace(qs, "logout=[^&]+", ""))>
		<cfset setValue("title","Logon")>
		<cfset setView("vwLogin")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspHome" access="public" returntype="void" output="false">
		<cfset setValue("title","Home")>
		<cfset setView("vwIndex")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspStats" access="public" returntype="void" output="false">
		<cfset var dsn = application.blog.getProperty("dsn")>
		<cfset var dbtype = application.blog.getProperty("blogdbtype")>
		<cfset var blog = application.blog.getProperty("name")>
		<cfset var thirtyDaysAgo = "">

		<!--- LM: All this should be in a Model call --->
		
		<!--- get a bunch of crap --->
		<cfquery name="rc.getTotalEntries" datasource="#dsn#">
				select	count(id) as totalentries,
						min(posted) as firstentry,
						max(posted) as lastentry
				from	tblblogentries
				where 	tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
		</cfquery>

		<cfquery name="rc.getTotalSubscribers" datasource="#dsn#">
			select	count(email) as totalsubscribers
			from	tblblogsubscribers
			where 	tblblogsubscribers.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
		</cfquery>
		
		<cfquery name="rc.getTotalViews" datasource="#dsn#">
			select		sum(views) as total
			from		tblblogentries
			where 	tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
		</cfquery>
		
		<cfquery name="rc.getTopViews" datasource="#dsn#">
			select		<cfif dbtype is not "mysql">top 10</cfif> id, title, views
			from		tblblogentries
			where 	tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
			order by	views desc
			<cfif dbtype is "mysql">limit 10</cfif>
		</cfquery>

		<!--- get last 30 --->
		<cfset thirtyDaysAgo = dateAdd("d", -30, now())>
		<cfquery name="rc.last30" datasource="#dsn#">
			select	count(id) as totalentries
			from	tblblogentries
			where 	tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
			and		posted >= <cfqueryparam cfsqltype="cf_sql_date" value="#thirtyDaysAgo#">
		</cfquery>
		
		<cfquery name="rc.getTotalComments" datasource="#dsn#">
			select	count(tblblogcomments.id) as totalcomments
			from	tblblogcomments, tblblogentries
			where	tblblogcomments.entryidfk = tblblogentries.id
			and		tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
		</cfquery>

		<!--- RBB: 1/20/2006: get trackbacks --->
		<cfquery name="rc.getTotalTrackbacks" datasource="#dsn#">
			select count(tblblogtrackbacks.id) as totaltrackbacks
			from	tblblogtrackbacks, tblblogentries
			where	tblblogtrackbacks.entryid = tblblogentries.id
			and		tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
		</cfquery>
		
		<!--- gets num of entries per category --->
		<cfquery name="rc.getCategoryCount" datasource="#dsn#">
			select	categoryid, categoryname, count(categoryidfk) as total
			from	tblblogcategories, tblblogentriescategories
			where	tblblogentriescategories.categoryidfk = tblblogcategories.categoryid
			and		tblblogcategories.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
			group by tblblogcategories.categoryid, tblblogcategories.categoryname
			<cfif dbtype is not "msaccess">
				order by total desc
			<cfelse>
				order by count(categoryidfk) desc
			</cfif>
		</cfquery>
		
		<!--- gets num of comments per entry, top 10 --->
		<cfquery name="rc.topCommentedEntries" datasource="#dsn#">
			select
			<cfif dbtype is not "mysql">top 10</cfif>
			tblblogentries.id, tblblogentries.title, count(tblblogcomments.id) as commentcount
			from			tblblogentries, tblblogcomments
			where			tblblogcomments.entryidfk = tblblogentries.id
			and				tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">

			group by		tblblogentries.id, tblblogentries.title
			<cfif dbtype is not "msaccess">
				order by	commentcount desc
			<cfelse>
				order by 	count(tblblogcomments.id) desc
			</cfif>
			<cfif dbtype is "mysql">limit 10</cfif>
		</cfquery>
		
		<!--- gets num of comments per category, top 10 --->
		<cfquery name="rc.topCommentedCategories" datasource="#dsn#">
			select
			<cfif dbtype is not "mysql">top 10</cfif>
							tblblogcategories.categoryid,
							tblblogcategories.categoryname,
							count(tblblogcomments.id) as commentcount
			from			tblblogcategories, tblblogcomments, tblblogentriescategories
			where			tblblogcomments.entryidfk = tblblogentriescategories.entryidfk
			and				tblblogentriescategories.categoryidfk = tblblogcategories.categoryid
			and				tblblogcategories.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
			group by		tblblogcategories.categoryid, tblblogcategories.categoryname
			<cfif dbtype is not "msaccess">
				order by	commentcount desc
			<cfelse>
				order by	count(tblblogcomments.id) desc
			</cfif>
			<cfif dbtype is "mysql">limit 10</cfif>
		</cfquery>
		
		<!--- RBB 1/20/2006: gets num of trackbacks per entry, top 10 --->
		<cfquery name="rc.topTrackbackedEntries" datasource="#dsn#">
			select
			<cfif dbtype is not "mysql">top 10</cfif>
			tblblogentries.id, tblblogentries.title, count(tblblogtrackbacks.id) as trackbackcount
			from			tblblogentries, tblblogtrackbacks
			where			tblblogtrackbacks.entryid = tblblogentries.id
			and				tblblogentries.blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">

			group by		tblblogentries.id, tblblogentries.title
			<cfif dbtype is not "msaccess">
				order by	trackbackcount desc
			<cfelse>
				order by 	count(tblblogtrackbacks.id) desc
			</cfif>
			<cfif dbtype is "mysql">limit 10</cfif>
		</cfquery>
		
		<cfquery name="rc.topSearchTerms" datasource="#dsn#">
			select
			<cfif dbtype is not "mysql">top 10</cfif>
						searchterm, count(searchterm) as total
			from		tblblogsearchstats
			where		blog = <cfqueryparam cfsqltype="cf_sql_varchar" value="#blog#">
			group by	searchterm
			<cfif dbtype is not "msaccess">
				order by	total desc
			<cfelse>
				order by	count(searchterm) desc
			</cfif>
			<cfif dbtype is "mysql">limit 10</cfif>
		</cfquery>
		
		<cfif rc.getTotalEntries.totalEntries>
			<cfset setValue("dur",dateDiff("d",rc.getTotalEntries.firstEntry, now()))>
		</cfif>

		<cfset setvalue("title",getresource("stats"))>
		<!--- Set View --->
		<cfset setView("vwStats")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspEntries" access="public" returntype="void" output="false">
		<cfset var params = structNew()>
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehEntry = "ehAdmin.dspEntry">
		<cfset rc.xehDeleteEntries = "ehAdmin.doDeleteEntries">
		
		<!--- Set params --->
		<cfset params.mode = "short">
		<cfif len(trim(getvalue("keywords","")))>
			<cfset params.searchTerms = getValue("keywords")>
			<cfset params.dontlogsearch = true>
		</cfif>
		<cfset setvalue("entries",application.blog.getEntries(params))>
		<cfset setValue("title","Entries")>
		<cfset setView("vwEntries")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspEntry" access="public" returntype="void" output="false">
		<!--- In coldbox you can use the form, url scopes too. You are open
		to use whatever you want. However, the request collection provides
		a one central repository, that any template, module, include can
		get --->
		<Cfset var entry = "">
		<cfset var message = "">
		
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehSave = "ehAdmin.doSaveEntry">
		
		<cftry>
			<cfif getvalue("id") neq 0>
				<cfset entry = application.blog.getEntry(getvalue("id"))>
				<cfif len(entry.morebody)>
					<cfset entry.body = entry.body & "<more/>" & entry.morebody>
				</cfif>			
				<!--- Param Values --->
				<cfset paramValue("title",entry.title)>
				<cfset paramValue("body",entry.body)>
				<cfset paramValue("alias",entry.alias)>	
				<cfset paramValue("posted",entry.posted)>
				<cfset paramValue("allowcomments",entry.allowcomments)>
				<cfset paramValue("oldenclosure",entry.enclosure)>
				<cfset paramValue("oldfilesize", entry.filesize)>
				<cfset paramValue("oldmimetype", entry.mimetype)>
				<cfset paramValue("released", entry.released)>
				
				<!--- handle case where form submitted, cant use cfparam --->
				<cfif not valueExists("save")>
					<cfset rc.categories = structKeyList(entry.categories)>
				</cfif>

			<cfelse>
				<!--- New Entry --->
				<cfif not valueExists("save") and not valueExists("return") and not valueExists("preview")>
					<cfset rc.categories = "">
				</cfif>
				<!--- Param Values --->
				<cfset paramValue("body", "")>
				<cfset paramValue("alias", "")>	
				<cfset paramValue("posted", "#dateAdd("h", application.blog.getProperty("offset"), now())#")>
				<cfset paramValue("allowcomments", "")>
				<cfset paramValue("oldenclosure", "")>
				<cfset paramValue("oldfilesize", "0")>
				<cfset paramValue("oldmimetype", "")>
				<cfset paramValue("released", "true")>
			</cfif>
			<cfcatch>
				<cfset getPlugin("logger").logError("Error in entries", cfcatch)>
				<cfset setNextEvent("ehAdmin.dspEntries")>
			</cfcatch>
		</cftry>
		
		<!---param Values --->
		<cfset paramValue("cboRelatedEntries", "")>
		<cfset paramValue("cboRelatedEntriesCats", "")>
		<cfset paramValue("newcategory", "")>
		
		<!--- Check oldfilesize --->
		<cfif not isNumeric(rc.oldfilesize)>
			<cfset rc.oldfilesize = 0>
		</cfif>
		<!--- check date --->
		<cfif lsIsDate(rc.posted)>
			<cfset rc.posted = createODBCDateTime(rc.posted)>
			<cfset rc.posted = application.localeUtils.dateLocaleFormat(rc.posted,"short") & " " & application.localeUtils.timeLocaleFormat(rc.posted)>
		</cfif>
		<cfset setValue("allCats",application.blog.getCategories())>
		<cfset setValue("message",message)>
		<cfset setValue("entry",entry)>
		<cfset setValue("title","Entry Editor")>
		<cfset setView("vwEntry")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doSaveEntry" access="public" returntype="void" output="false">
		<cfset var errors = arrayNew(1)>
		<cfset var entry = "">
		<cfset var destination = "">
		<cfset var origbody = "">
		<cfset var strMoreTag = "">
		<cfset var moreStart = "">
		<cfset var moreText = "">
	
		<!--- Param Values --->
		<cfset paramValue("cboRelatedEntries", "")>
		<cfset paramValue("cboRelatedEntriesCats", "")>
		<cfset paramValue("newcategory", "")>

		<!--- Check for cancel --->
		<cfif valueExists("cancel")>
			<cfset setNextEvent("ehAdmin.dspEntries")>
		</cfif>
	
		<!--- check for delete enclosure --->
		<cfif valueExists("delete_enclosure")>
			<cfif len(rc.oldenclosure) and fileExists(rc.oldenclosure)>
				<cffile action="delete" file="#rc.oldenclosure#">
			</cfif>
			<cfset rc.oldenclosure = "">
			<cfset rc.oldfilesize = "0">
			<cfset rc.oldmimetype = "">
			<!--- We need to set a msg to warn folks that they need to save the entry --->
			<cfif rc.id is not "new">
				<cfset message = getResource("enclosureentrywarning")>
			</cfif>
		</cfif>

		<!---
		Enclosure logic move out to always run. Thinking is that it needs to run on preview.
		--->
		<cfif valueExists("enclosure") and len(trim(rc.enclosure))>
			<cfset destination = expandPath("../enclosures")>
			<!--- first off, potentially make the folder --->
			<cfif not directoryExists(destination)>
				<cfdirectory action="create" directory="#destination#">
			</cfif>

			<cffile action="upload" filefield="enclosure" destination="#destination#" nameconflict="makeunique">
			<cfif cffile.filewassaved>
				<cfset rc.oldenclosure = cffile.serverDirectory & "/" & cffile.serverFile>
				<cfset rc.oldfilesize = cffile.filesize>
				<cfset rc.oldmimetype = cffile.contenttype & "/" & cffile.contentsubtype>
			</cfif>
		</cfif>

		<!--- Save Entry --->
		<cfif valueExists("save")>
			<cfif not len(trim(rc.title))>
				<cfset arrayAppend(errors, getResource("mustincludetitle"))>
			<cfelse>
				<cfset rc.title = trim(rc.title)>
			</cfif>
			<cfif not isDate(rc.posted)>
				<cfset arrayAppend(errors, getResource("invaliddate"))>
			</cfif>
			<cfif not len(trim(rc.body))>
				<cfset arrayAppend(errors, getResource("mustincludebody"))>
				<cfset origbody = "">
			<cfelse>
				<cfset rc.body = trim(rc.body)>
				<cfset origbody = rc.body>

				<!--- Handle potential <more/> --->
				<!--- fix by Andrew --->
				<cfset strMoreTag = "<more/>">
				<cfset moreStart = findNoCase(strMoreTag,rc.body)>
				<cfif moreStart gt 1>
					<cfset moreText = trim(mid(rc.body,(moreStart+len(strMoreTag)),len(rc.body)))>
					<cfset rc.body = trim(left(rc.body,moreStart-1))>
				<cfelseif moreStart is 1>
					<cfset arrayAppend(errors, getResource("mustincludebody"))>
				<cfelse>
					<cfset moreText = "">
				</cfif>
			</cfif>
			<!--- Categories --->
			<cfif (not valueExists("categories") or rc.categories is 0) and not len(trim(rc.newCategory))>
				<cfset arrayAppend(errors, getResource("mustincludecategory"))>
			<cfelse>
				<cfset rc.newCategory = trim(htmlEditFormat(rc.newCategory))>
			</cfif>

			<cfif len(rc.alias)>
				<cfset rc.alias = trim(htmlEditFormat(rc.alias))>
			<cfelse>
				<!--- Auto create the alias --->
				<cfset rc.alias = application.blog.makeTitle(rc.title)>
			</cfif>

			<cfif not arrayLen(errors)>
				<!--- Before we save, modify the posted time by -1 * posted --->
				<cfset rc.posted = dateAdd("h", -1 * application.blog.getProperty("offset"), rc.posted)>
				<cfif getvalue("id") neq 0>
					<cfset application.blog.saveEntry(rc.id,rc.title,rc.body,moreText,rc.alias,rc.posted,rc.allowcomments, rc.oldenclosure, rc.oldfilesize, rc.oldmimetype,rc.released,rc.cboRelatedEntries)>
				<cfelse>
					<cfset rc.id = application.blog.addEntry(rc.title,rc.body,moreText,rc.alias,rc.posted,rc.allowcomments, rc.oldenclosure, rc.oldfilesize, rc.oldmimetype,rc.released,rc.cboRelatedEntries)>
				</cfif>
				<!--- remove all old cats that arent passed in --->
				<cfif rc.id is not "new">
					<cfset application.blog.removeCategories(rc.id)>
				</cfif>
				<!--- potentially add new cat --->
				<cfif len(trim(rc.newCategory))>
					<cfset paramValue("categories", "")>
					<cfset rc.categories = listAppend(rc.categories,application.blog.addCategory(rc.newCategory, application.blog.makeTitle(rc.newCategory)))>
				</cfif>
				<cfset application.blog.assignCategories(rc.id,rc.categories)>
				<cfmodule template="../../tags/scopecache.cfm" scope="application" clearall="true">
				<cfset setNextEvent("ehAdmin.dspEntries")>
			<cfelse>
				<!--- restore body, since it loses more body --->
				<cfset rc.body = origbody>
			</cfif>
		</cfif>
		
		<!--- Run internal event to display entry --->
		<cfset dspEntry()>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doDeleteEntries" access="public" returntype="void" output="false">
		<cfset var u = "">
		<cfloop index="u" list="#getValue("mark","")#">
			<cfset application.blog.deleteEntry(u)>
		</cfloop>
		<cfset setNextEvent("ehAdmin.dspEntries")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doDeleteTrackbacks" access="public" returntype="void" output="false">
		<cfset var u = "">
		<cfloop index="u" list="#getValue("mark","")#">
			<cfset application.blog.deleteTrackback(u)>
		</cfloop>
		<cfset setNextEvent("ehAdmin.dspTrackbacks")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspTrackbacks" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehTrackback = "ehAdmin.dspTrackback">
		<cfset rc.xehDeleteTrackbacks = "ehAdmin.doDeleteTrackbacks">
		
		<cfset setvalue("tbs", application.blog.getTrackbacks(sortdir="desc"))>
		<cfset setValue("title","Trackbacks")>
		<cfset setView("vwTrackbacks")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doDeleteCategories" access="public" returntype="void" output="false">
		<cfset var u = "">
		<cfloop index="u" list="#getValue("mark","")#">
			<cfset application.blog.deleteCategory(u)>
		</cfloop>
		<cfset setNextEvent("ehAdmin.dspCategories")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspCategories" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehCategory = "ehAdmin.dspCategory">
		<cfset rc.xehDeleteCategory = "ehAdmin.doDeleteCategories">
		
		<cfset setvalue("categories", application.blog.getCategories())>
		<cfset setValue("title","Trackbacks")>
		<cfset setView("vwCategories")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspCategory" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehSaveCategory = "ehAdmin.doAddCategory">
		<cftry>
			<cfif getvalue("id",0) neq 0>
				<cfset setvalue("cat",application.blog.getCategory(getvalue("id")))>
				<cfset setvalue("name",getvalue("cat.categoryname"))>
				<cfset setvalue("alias",getvalue("cat.categoryalias"))>
			</cfif>
			<cfcatch>
				<cfset setNextEvent("ehAdmin.dspCategories")>
			</cfcatch>
		</cftry>

		<cfset setValue("title","Category Editor")>
		<cfset setView("vwCategory")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doAddCategory" access="public" returntype="void" output="false">
		<cfset var errors = arrayNew(1)>

		<cfif valueExists("cancel")>
			<cfset setNextEvent("ehAdmin.dspCategories")>
		</cfif>

		<cfif not len(trim(getValue("name")))>
			<cfset arrayAppend(errors, "The name cannot be blank.")>
		</cfif>
		<cfif not len(trim(getValue("alias")))>
			<cfset setvalue("alias",application.blog.makeTitle(getValue("name")))>
		<cfelseif reFind("[^[:alnum:] -]", getvalue("alias"))>
			<cfset arrayAppend(errors, "Your alias may only contain letters, numbers, spaces, or hyphens.")>
		</cfif>
		<cfif not arrayLen(errors)>
			<cftry>
			<cfif getvalue("id") neq 0>
				<cfset application.blog.saveCategory(getvalue("id"), left(getValue("name"),50), left(getvalue("alias"), 50))>
			<cfelse>
				<cfset application.blog.addCategory(left(getValue("name"),50), left(getvalue("alias"),50))>
			</cfif>
			<cfcatch>
				<cfif findNoCase("already exists as a category", cfcatch.message)>
					<cfset arrayAppend(errors, "A category with this name already exists.")>
				<cfelse>
					<cfrethrow>
				</cfif>
			</cfcatch>
			</cftry>

			<cfif not arrayLen(errors)>
				<!--- clear the archive pod cache --->
				<cfmodule template="../../tags/scopecache.cfm" action="clear" scope="application" cachename="pod_archives" />
				<cfset setNextEvent("ehAdmin.dspCategories")>
			</cfif>
		</cfif>
		<cfset setvalue("errors",errors)>
		<cfset setNextEvent("ehAdmin.dspCategory","id=#getvalue("id")#")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspComments" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehComment = "ehAdmin.dspComment">
		<cfset rc.xehDeleteComment = "ehAdmin.doDeleteComments">
		
		<cfset setvalue("comments", application.blog.getComments(sortdir="desc"))>
		<cfset setValue("title","Comments")>
		<cfset setView("vwComments")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doDeleteComments" access="public" returntype="void" output="false">
		<cfset var u = "">
		<cfloop index="u" list="#getValue("mark","")#">
			<cfset application.blog.deleteComment(u)>
		</cfloop>
		<cfset setNextEvent("ehAdmin.dspComments")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspComment" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehAddComment = "ehAdmin.doAddComment">
		
		<cftry>
			<cfset setvalue("comment", application.blog.getComment(getvalue("id")))>
			<cfif getvalue("comment.recordCount") is 0>
				<cfset setNextEvent("ehAdmin.dspComments")>
			</cfif>
			<cfcatch>
				<cfset setNextEvent("ehAdmin.dspComments")>
			</cfcatch>
		</cftry>
		<cfset setValue("title","Comment Editor")>
		<cfset setView("vwComment")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doAddComment" access="public" returntype="void" output="false">
		<cfset var errors = arrayNew(1)>

		<cfif valueExists("cancel")>
			<cfset setNextEvent("ehAdmin.dspComments")>
		</cfif>

		<cfif not len(trim(getvalue("name")))>
			<cfset arrayAppend(errors, "The name cannot be blank.")>
		</cfif>
		<cfif not len(trim(getvalue("email"))) or not isEmail(getvalue("email"))>
			<cfset arrayAppend(errors, "The email cannot be blank and must be a valid email address.")>
		</cfif>
		<cfif len(getvalue("website")) and not isURL(getvalue("website"))>
			<cfset arrayAppend(errors, "Website must be a valid URL.")>
		</cfif>
		<cfif not len(trim(getvalue("newcomment")))>
			<cfset arrayAppend(errors, "The comment cannot be blank.")>
		</cfif>
		<cfif not arrayLen(errors)>
			<cfset application.blog.saveComment(getvalue("id"), left(getvalue("name"),50), left(getvalue("email"),50), left(getvalue("website"),255), getvalue("newcomment"), getvalue("subscribe",false))>
			<cfset setNextEvent("ehAdmin.dspComments")>
		</cfif>
		<cfset setvalue("errors",errors)>
		<cfset setNextEvent("ehAdmin.dspComment","id=#getvalue("id")#")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspSubscribers" access="public" returntype="void" output="false">
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehDeleteSub = "ehAdmin.doDeleteSubscribers">
		<cfset setvalue("subscribers", application.blog.getSubscribers())>
		<cfset setValue("title","Subscribers")>
		<cfset setView("vwSubscribers")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doDeleteSubscribers" access="public" returntype="void" output="false">
		<cfset var u = "">
		<cfloop index="u" list="#getValue("MARK","")#">
			<cfset application.blog.removeSubscriber(u)>
		</cfloop>
		<cfset setNextEvent("ehAdmin.dspSubscribers")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="dspSettings" access="public" returntype="void" output="false">
		<cfset var settings = application.blog.getProperties()>
		<cfset var validDBTypes = application.blog.getValidDBTypes()>
		<!--- EXIT HANDLERS: --->
		<cfset rc.xehSaveSettings = "ehAdmin.doSaveSettings">
		<cfloop item="setting" collection="#settings#">
			<cfset paramValue("#setting#", settings[setting])>			
		</cfloop>
		<cfset setvalue("settings",settings)>
		<Cfset setvalue("validDBTypes",validDBTypes)>
		<cfset setValue("title","Settings")>
		<cfset setView("vwSettings")>
	</cffunction>
	<!--- ************************************************************* --->

	<!--- ************************************************************* --->
	<cffunction name="doSaveSettings" access="public" returntype="void" output="false">
		<cfset var errors = arrayNew(1)>
		<cfset var keylist = "">
		
		<cfif valueExists("cancel")>
			<cfset setNextEvent("ehAdmin.dspHome")>
		</cfif>

		<cfif not len(trim(getvalue("blogtitle")))>
			<cfset arrayAppend(errors, "Your blog must have a title.")>
		</cfif>

		<cfif not len(trim(getvalue("blogurl")))>
			<cfset arrayAppend(errors, "Your blog url cannot be blank.")>
		<cfelseif right(getvalue("blogurl"), 9) is not "index.cfm">
			<cfset arrayAppend(errors, "The blogurl setting must end with index.cfm.")>
		</cfif>

		<cfif len(trim(getvalue("commentsfrom"))) and not isEmail(getvalue("commentsfrom"))>
			<cfset arrayAppend(errors, "The commentsfrom setting must be a valid email address.")>
		</cfif>

		<cfif len(trim(getvalue("maxentries"))) and not isNumeric(getvalue("maxentries"))>
			<cfset arrayAppend(errors, "Max entries must be numeric.")>
		</cfif>

		<cfif len(trim(getvalue("offset"))) and not isNumeric(getvalue("offset"))>
			<cfset arrayAppend(errors, "Offset must be numeric.")>
		</cfif>

		<cfset setvalue("pingurls",toList(getvalue("pingurls")))>

		<cfif not len(trim(getvalue("dsn")))>
			<cfset arrayAppend(errors, "Your blog must have a dsn.")>
		</cfif>

		<cfif not len(trim(getvalue("locale")))>
			<cfset arrayAppend(errors, "Your blog must have a locale.")>
		</cfif>

		<cfset setvalue("ipblocklist", toList(getvalue("ipblocklist")))>
		<cfset setvalue("trackbackspamlist", toList(getvalue("trackbackspamlist")))>

		<cfif not arrayLen(errors)>
			<!--- make a list of the keys we will send. --->
			<cfset keylist = "blogtitle,blogdescription,blogkeywords,blogurl,commentsfrom,maxentries,offset,pingurls,dsn,blogdbtype,locale,ipblocklist,allowtrackbacks,trackbackspamlist,mailserver,mailusername,mailpassword,users,usecaptcha">
			<cfloop index="key" list="#keylist#">
				<cfset application.blog.setProperty(key, trim(rc[key]))>
			</cfloop>
			<cfset getPlugin("messagebox").setMessage("info","Settings have been updated successfully.")>
			<cfset setNextEvent("ehAdmin.dspHome","reinit=1")>
		</cfif>
		<cfset setView("vwSettings")>
	</cffunction>
	<!--- ************************************************************* --->

</cfcomponent>