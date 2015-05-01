jsoniq version "1.0";
module namespace ml = "http://28.io/modules/marklogic";

import module namespace http =
    "http://28.io/modules/http-client-wrapper";

import module namespace credentials =
    "http://www.28msec.com/modules/credentials";

declare %private variable $ml:category as string := "MarkLogic";

declare %private variable $ml:BASE_PATH as string := "/v1";

declare %private variable $ml:UNSUPPORTED_BODY as QName :=
    QName("ml:UNSUPPORTED_BODY");

declare %private function ml:parse-sequence(
    $parts as object*
) as item* {
    for $part in $parts
    let $primitive := $part.headers("X-Primitive")
    let $value := $part.body.content
    let $item :=
        switch($primitive)
        case "integer" return integer($value)
        case "string"  return string($value)
        case "anyURI"  return anyURI($value)
        case "QName"   return QName($value)
        case "boolean" return boolean($value)
        case "decimal" return decimal($value)
        case "double"  return double($value)
        case "float"   return float($value)
        case "base64Binary" return base64Binary($value)
        case "date" return date($value)
        case "dateTime" return dateTime($value)
        case "time" return time($value)
        case "gMonth" return gMonth($value)
        case "gMonthDay" return gMonthDay($value)
        case "gYear" return gYear($value)
        case "gYearMonth" return gYearMonth($value)
        case "duration" return duration($value)
        case "dayTimeDuration" return dayTimeDuration($value)
        case "yearMonthDuration" return yearMonthDuration($value)
        case "node-object" return parse-json($value)
        default return
            if(contains($part.body("media-type"), "xml")) then
                parse-xml($value)
            else if(contains($part.body("media-type"), "json")) then
                parse-json($value)
            else $value
    return $item
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string) as object {
    ml:send-request($name, $path, "POST")
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string) as object {
    ml:send-request($name, $path, $method, ())
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object?) as object {
    ml:send-request($name, $path, $method, $query-parameters, ())
};

declare %an:sequential %private function ml:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object?,
    $body as item?) as object {
    ml:send-request($name, $path, $method, $query-parameters, $body, ())
};

declare %an:sequential %private function ml:send-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as object {
    let $request :=
      ml:request($name, $path, $method, $query-parameters, $body, $headers)
    return http:send-request($request)
};

declare %private function ml:send-deterministic-request(
      $name as string,
      $path as string) as object {
    ml:send-deterministic-request($name, $path, "GET")
};

declare %private function ml:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string) as object {
    ml:send-deterministic-request($name, $path, $method, ())
};

declare %private function ml:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?) as object {
    ml:send-deterministic-request($name, $path, $method, $query-parameters, ())
};

declare %private function ml:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?) as object {
    ml:send-deterministic-request($name, $path, $method, $query-parameters, $body, ())
};

declare %private function ml:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as item* {
    let $request :=
      ml:request($name, $path, $method, $query-parameters, $body, $headers)
    let $response :=
      http:send-deterministic-request($request)
    return switch($response.status)
           case 200 return ml:response($response)
           case 400 return error(QName("ml:BAD_REQUEST"), "Unsupported or invalid parameters, or missing required parameters.", $response)
           case 401 return error(QName("ml:UNAUTHORIZED"), "User is not authorized.", $response)
           case 403 return error(QName("ml:FORBIDDEN"), "User does not have access to this resource.", $response)
           case 404 return error(QName("ml:NOT_FOUND"), "No matching pattern for incoming URI.", $response)
           case 405 return error(QName("ml:METHOD_NOT_ALLOWED"), "The service does not support the HTTP method used by the client.", $response)
           case 406 return error(QName("ml:UNACCEPTABLE_TYPE"), "Unable to provide content type matching the client's Accept header.", $response)
           case 412 return error(QName("ml:PRECONDITION_FAILED"), "A non-syntactic part of the request was rejected. For example, an empty POST or PUT body.", $response)
           case 415 return error(QName("ml:UNSUPPORTED_MEDIA_TYPE"), "A PUT or POST payload cannot be accepted.", $response)
           default return error(QName("ml:UNKNOWN_ERROR"), "Unknown error (status " || $response.status || ")", $response)
};

declare %private function ml:response(
    $response as object
) as item* {
    let $media := $response.body("media-type")
    return
        if(contains($media, "json")) then
            parse-json($response.body.content)
        else if($response.multipart) then
            ml:parse-sequence($response.multipart.parts[])
        else
            $response.body.content
};

declare %private function ml:request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as object {
    let $credentials := credentials:credentials($ml:category, $name)
    return {|
        {
            href: "http://" ||
                  $credentials.hostname || ":" ||
                  $credentials.port || $ml:BASE_PATH[not starts-with($path, $ml:BASE_PATH)] ||
                  $path || (
                      if(exists($query-parameters))
                      then "?" ||
                        string-join(for $parameter in keys($query-parameters)
                                    for $value as string in
                                        flatten($query-parameters.$parameter) ! string($$)
                                    return $parameter || "=" ||
                                           encode-for-uri($value),
                                    "&")
                      else ""
                  ),
            method: $method,
            headers: if($headers) then $headers else {},
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
                              "media-type" : ($headers("Content-Type"), "application/json;charset=UTF-8")[1],
                              "content" : serialize($body)
                          }
                          case string return {
                              "media-type": ($headers("Content-Type"), "text/plain")[1],
                              "content": $body
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
as ()
{
    ml:send-request($name, "/documents", "PUT", { uri: $uri }, $document);
};

declare function ml:document(
    $name as string,
    $uri as string)
as object
{
    ml:send-deterministic-request($name, "/documents", "GET", { uri: $uri })
};

declare function ml:qbe(
    $name as string,
    $collection as string)
as object*
{
    ml:qbe($name, $collection, {})
};

declare function ml:qbe(
    $name as string,
    $collection as string,
    $query as object)
as object*
{
    let $response := ml:send-deterministic-request(
        $name,
        "/qbe",
        "POST",
        { collection: $collection, pageLength: 10000 },
        { "$query" : $query },
        { Accept: "multipart/mixed; boundary=DEFAULT_BOUNDARY_14201231297125830186" }
    )
    return $response
};

declare function ml:count(
    $name as string,
    $collection as string
) as integer {
    ml:simple-query($name, "count(collection(\"" || $collection || "\"))")
};

declare function ml:simple-query(
    $name as string,
    $query as string
) as item* {
    ml:send-deterministic-request($name, "/eval", "POST", { pageLength: 10000 }, "xquery=" || $query, { "Content-Type": "application/x-www-form-urlencoded" })
};

declare %an:sequential function ml:query(
    $name as string,
    $query as string
) as item* {
    ml:send-request($name, "/eval", "POST", { pageLength: 10000 }, "xquery=" || $query, { "Content-Type": "application/x-www-form-urlencoded" })
};
