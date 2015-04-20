import module namespace http = "http://zorba.io/modules/http-client";

declare namespace html = "http://www.w3.org/1999/xhtml";

let $resources := {
    "/config/resources": ["GET"],
    "/config/resources/{name}": ["GET", "PUT", "DELETE"],
    "/eval": ["POST"],
    "/ext/{directories}": ["GET", "DELETE"]
}
return {
    "swagger": "2.0",
    "info": {
        "title": "MarkLogic API",
        "description": "Marklogic REST API",
        "version": "8.0.0"
    },
    "host": "localhost",
    "schemes": [
        "http"
    ],
    "basePath": "/v1",
    "produces": [
        "application/json",
        "application/xml"
    ],
    "parameters": {},
    "paths": {|
        for $resource in jn:keys($resources)
        return {
            $resource: {|
                for $method in $resources($resource)[]
                let $content := http:get("https://docs.marklogic.com/REST/" || $method || "/v1" || $resource).body.content
                let $content := parse-xml($content)//html:div[string($$/@class) eq "pjax_enabled"]
                let $summary := $content/html:h3[string($$) eq "Summary"]/following-sibling::html:p[1]/string()
                let $tables  := $content/html:table[string($$/@class) eq "parameters"]
                return {
                    $method: {
                        "summary": $method || " " || $resource,
                        "description": normalize-space($summary),
                        "parameters": [
                            for $table in $tables
                            let $header := $table/html:thead/html:tr/html:th/string()
                            let $header := normalize-space($header)
                            where starts-with($header, "Request ") or starts-with($header, "URL ")
                            let $in := if($header eq "Request Headers") then
                                            "header"
                                        else if($header eq "URL Parameters") then
                                            "query"
                                        else ""
                            for $parameter in $table/html:tbody/html:tr
                            let $raw-name := $parameter/html:td[1]/string()
                            let $arity := substring($raw-name, string-length($raw-name))
                            let $has-arity := $arity eq "*" or  $arity eq "?" or  $arity eq "+"
                            let $required := not($has-arity) or $arity eq "+"
                            let $name := if($has-arity) then substring($raw-name, 1, string-length($raw-name) - 1) else $raw-name
                            return {
                                "name": $name,
                                "in": $in,
                                "description": normalize-space($parameter/html:td[2]/string()),
                                "required": $required
                            }
                        ]
                    }
                }
            |}
        }
    |}
}
