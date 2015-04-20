module namespace ml = "http://28.io/modules/marklogic";

import module namespace credentials =
    "http://www.28msec.com/modules/credentials";
import module namespace http =
    "http://zorba.io/modules/http-client";

declare %private variable $ml:category as string := "MarkLogic";

declare %private variable $ml:UNSUPPORTED_BODY as QName :=
    QName("ml:UNSUPPORTED_BODY");

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
        $name as string,
        $endpoint as string) as string {
    ml:send-nondeterministic-request($name, $endpoint, "GET", (), ())
};

declare %an:sequential %private function ml:send-request(
        $name as string,
        $endpoint as string,
        $method as string) as string {
    ml:send-request($name, $endpoint, $method, (), ())
};

declare %an:sequential %private function ml:send-request(
      $name as string,
      $endpoint as string,
      $method as string,
      $url-parameters as object) as string {
    ml:send-request($name, $endpoint, $method, $url-parameters, ())
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $endpoint as string,
      $method as string,
      $url-parameters as object) as string {
    ml:send-nondeterministic-request(
        $name, $endpoint, $method, $url-parameters, ())
};

declare %an:sequential %private function ml:send-request(
      $name as string,
      $endpoint as string,
      $method as string,
      $url-parameters as object?,
      $body as item?) as string {
    let $request :=
        ml:request($name, $endpoint, $method, $url-parameters, $body)
    return http:send-request($request)
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $endpoint as string,
      $method as string,
      $url-parameters as object?,
      $body as item?) as string {
    let $request :=
        ml:request($name, $endpoint, $method, $url-parameters, $body)
    return http:send-nondeterministic-request($request)
};

declare %private function ml:request(
      $name as string,
      $endpoint as string,
      $method as string,
      $url-parameters as object?,
      $body as item?) as string {
    let $credentials := credentials:credentials($ml:category, $name)
    return {|
        {
            href: "http://" ||
                  $credentials.hostname || ":" ||
                  $credentials.port || "/v1/" ||
                  $endpoint ||
                  (
                      if(exists($url-parameters))
                      then "?" ||
                        string-join(for $parameter in keys($url-parameters)
                                    for $value as string in
                                        flatten($url-parameters.$parameter)
                                    return $parameter || ":" ||
                                           encode-for-uri($value),
                                    "&")
                      else ""
                  ),
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
                              "content" : serialize($body)
                          }
                          default return error($ml:UNSUPPORTED_BODY)
                    |}
                }
            else ()
        |}
    |}
};

declare %an:sequential function ml:put-document(
    $name as string,
    $uri as string,
 $document as object)
as empty-sequence()
{
    ml:send-request($name, "documents", "PUT", { uri: $uri }, $document)
};

declare %an:nondeterministic function ml:get-document(
    $name as string,
    $uri as string)
as object()
{
    ml:send-nondeterministic-request($name, "documents", "GET", { uri: $uri })
};

declare %an:nondeterministic function ml:qbe(
    $name as string,
    $collection as string,
    $query as object)
as object()
{
    ml:send-nondeterministic-request(
        $name,
        "qbe",
        "GET",
        { collection: $collection },
        $query)
};
