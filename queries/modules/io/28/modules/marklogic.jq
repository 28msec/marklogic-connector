module namespace ml = "http://28.io/modules/marklogic";

import module namespace credentials =
    "http://www.28msec.com/modules/credentials";
import module namespace http =
    "http://zorba.io/modules/http-client";

declare %private variable $ml:category as string := "MarkLogic";

declare %private variable $ml:BASE_PATH as string := "/v1";

declare %private variable $ml:UNSUPPORTED_BODY as QName :=
    QName("ml:UNSUPPORTED_BODY");

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string) as object {
    ml:send-request($name, $path, "POST", {}, (), {})
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string) as object {
    ml:send-request($name, $path, $method, {}, (), {})
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object) as object {
    ml:send-request($name, $path, $method, $query-parameters, (), {})
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object,
    $body as item?) as object {
    ml:send-request($name, $path, $method, $query-parameters, $body, {})
};

declare %an:sequential %private function ml:send-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object,
      $body as item?,
      $headers as object) as object {
    let $request :=
      ml:request($name, $path, $method, $query-parameters, $body, $headers)
    return http:send-request($request)
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $path as string) as object {
    ml:send-nondeterministic-request($name, $path, "GET", {}, (), {})
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $path as string,
      $method as string) as object {
    ml:send-nondeterministic-request($name, $path, $method, {}, (), {})
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object) as object {
    ml:send-nondeterministic-request($name, $path, $method, $query-parameters, (), {})
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object,
      $body as item?) as object {
    ml:send-nondeterministic-request($name, $path, $method, $query-parameters, $body, {})
};

declare %an:nondeterministic %private function ml:send-nondeterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object,
      $body as item?,
      $headers as object) as object {
    let $request :=
      ml:request($name, $path, $method, $query-parameters, $body, $headers)
    return http:send-nondeterministic-request($request)
};

declare %private function ml:request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object) as object {
    let $credentials := credentials:credentials($ml:category, $name)
    return {|
        {
            href: "http://" ||
                  $credentials.hostname || ":" ||
                  $credentials.port || $ml:BASE_PATH ||
                  $path || (
                      if(exists($query-parameters))
                      then "?" ||
                        string-join(for $parameter in keys($query-parameters)
                                    for $value as string in
                                        flatten($query-parameters.$parameter)
                                    return $parameter || "=" ||
                                           encode-for-uri($value),
                                    "&")
                      else ""
                  ),
            method: $method,
            headers: $headers,
            authentication: {
                username: $credentials.username,
                password: $credentials.password,
                "auth-method": "Digest"
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
    ml:send-request($name, "/documents", "PUT", { uri: $uri }, $document);
};

declare %an:nondeterministic function ml:get-document(
    $name as string,
    $uri as string)
as object()
{
    ml:send-nondeterministic-request($name, "/documents", "GET", { uri: $uri })
};

declare %an:nondeterministic function ml:qbe(
    $name as string,
    $collection as string,
    $query as object)
as object()
{
    ml:send-nondeterministic-request(
        $name,
        "/qbe",
        "POST",
        { collection: $collection },
        $query)
};
