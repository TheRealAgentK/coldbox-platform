﻿<cfcomponent output="false">
	<!--- Default Action ---><cffunction name="index" returntype="void" output="false" hint="My main event">
		<cfargument name="event" required="true"><cfscript>
		var rc = event.getCollection();
		event.paramValue( "layout", "module-level" );
		event.paramValue( "view", "module-level" );
		event.setLayout( rc.layout );
		event.setView( rc.view );
		</cfscript>
	</cffunction>
	<!------------------------------------------- PRIVATE EVENTS ------------------------------------------>
</cfcomponent>
