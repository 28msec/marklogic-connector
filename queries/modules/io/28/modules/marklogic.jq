module namespace ml = "http://28.io/modules/marklogic";

import module namespace credentials = "http://www.28msec.com/modules/credentials";
import module namespace http = "http://zorba.io/modules/http-client";

declare %private variable $ml:category as string := "MarkLogic";

declare %private variable $ml:UNSUPPORTED_BODY as QName := QName("ml:UNSUPPORTED_BODY");

declare %an:sequential %private function ml:send-request($name as string, $uri as string) as string {
    ml:send-request($name, "GET", $uri, ())
};

declare %an:sequential %private function ml:send-request($name as string, $method as string, $uri as string) as string {
    ml:send-request($name, $method, $uri, ())
};

declare %an:sequential %private function ml:send-request($name as string, $method as string, $uri as string, $body as item?) as string {
    let $credentials := credentials:credentials($ml:category, $name)
    return http:send-request({|
        {
            href: "http://" || $credentials.hostname || ":" || $credentials.port || "/" || $uri,
            method: $method,
            authentication: {
                username: $credentials.username,
                password: $credentials.password,
                "auth-method": "Basic"
            }
        }
        ,
        {|
            if($body) then
                {
                    body: {|
                          typeswitch($body)
                          case json-item return {
                              "media-type" : "application/json;charset=UTF-8",
                              "content" : $body
                          }
                          default return error($ml:UNSUPPORTED_BODY)
                    |}
                }
            else ()
        |}
    |})
};

declare %an:sequential function ml:put-document($name as string, $uri as string, $document as object)
as empty-sequence()
{
    ml:send-request($name, "PUT", $uri, $document)
};

declare %an:sequential function ml:get-document($name as string, $uri as string)
as object()
{
    ml:send-request($name, "GET", $uri)
};
