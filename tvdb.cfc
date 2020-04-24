component {

	function init(
		required string apiKey
	,	string apiUrl="https://api.thetvdb.com"
	,	string apiVersion=""
	,	numeric throttle=500
	,	numeric httpTimeOut=60
	,	boolean debug
	) {
		arguments.debug = ( arguments.debug ?: request.debug ?: false );
		this.apiKey= arguments.apiKey;
		this.apiUrl= arguments.apiUrl;
		this.apiVersion= arguments.apiVersion;
		this.httpTimeOut= arguments.httpTimeOut;
		this.throttle= arguments.throttle;
		this.debug= arguments.debug;
		this.lastRequest= server.tvdb_lastRequest ?: 0;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "TVDb: " & arguments.input );
			} else {
				request.log( "TVDb: (complex type)" );
				request.log( arguments.input );
			}
		} else {
			var info= ( isSimpleValue( arguments.input ) ? arguments.input : serializeJson( arguments.input ) );
			cftrace(
				var= "info"
			,	category= "TVDb"
			,	type= "information"
			);
		}
		return;
	}

	struct function apiRequest( required string api, string lang="" ) {
		var http= {};
		var out= {
			success= false
		,	verb= listFirst( arguments.api, " " )
		,	requestUrl= this.apiUrl & listRest( arguments.api, " " )
		,	error= ""
		,	status= ""
		,	statusCode= 0
		,	response= ""
		,	lang= arguments.lang
		,	delay= 0
		};
		arguments[ "apikey" ]= this.apiKey;
		structDelete( arguments, "api" );
		structDelete( arguments, "lang" );
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		// throttle requests by sleeping the thread to prevent overloading api
		if ( this.lastRequest > 0 && this.throttle > 0 ) {
			out.delay= this.throttle - ( getTickCount() - this.lastRequest );
			if ( out.delay > 0 ) {
				this.debugLog( "Pausing for #out.delay#/ms" );
				sleep( out.delay );
			}
		}
		cftimer( type="debug", label="tvdb request" ) {
			cfhttp( result="http", method=out.verb, url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut ) {
				if ( len( out.lang ) ) {
					cfhttpparam( name="Accept-Language", type="header", value=out.lang );
				}
				if ( len( this.apiVersion ) ) {
					cfhttpparam( name="Accept", type="header", value="application/vnd.thetvdb.v#this.apiVersion#" );
				}
			}
			if ( this.throttle > 0 ) {
				this.lastRequest= getTickCount();
				server.tvdb_lastRequest= this.lastRequest;
			}
		}
		out.response= toString( http.fileContent );
		// this.debugLog( http );
		// this.debugLog( out.response );
		out.statusCode= http.responseHeader.Status_Code ?: 500;
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		if ( len( out.response ) ) {
			try {
				out.json= deserializeJSON( out.response );
				if ( isStruct( out.json ) && structKeyExists( out.json, "status" ) && out.json.status == "error" ) {
					out.success= false;
					out.error= out.json.message;
				}
				if ( structCount( out.json ) == 1 ) {
					out.json= out.json[ structKeyList( out.json ) ];
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	struct function search( required string q ) {
		var out= this.apiRequest(
			api= "GET /search/series"
		,	name= arguments.q
		);
		return out;
	}

	struct function seriesInfo( required string id, string lang="" ) {
		var out= this.apiRequest(
			api= "GET /series/#arguments.id#"
		,	lang= arguments.lang
		);
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode=true, string lExclude="", string sDelims="," ) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= "?";
		for ( sItem in stInput ) {
			if ( !len( lExclude ) || !listFindNoCase( lExclude, sItem, sDelims ) ) {
				try {
					sValue= stInput[ sItem ];
					if ( len( sValue ) ) {
						if ( bEncode ) {
							sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue );
						} else {
							sOutput &= amp & lCase( sItem ) & "=" & sValue;
						}
						amp= "&";
					}
				} catch (any cfcatch) {
				}
			}
		}
		return sOutput;
	}

}
