jsoniq version "1.0";
module namespace yi = "http://28.io/modules/yidb";

import module namespace http =
    "http://28.io/modules/http-client-wrapper";

import module namespace string =
    "http://zorba.io/modules/string";

import module namespace credentials =
    "http://www.28msec.com/modules/credentials";

declare %private variable $yi:category as string := "YiDB";

declare %private variable $yi:BASE_PATH as string := "/cms";

declare %private variable $yi:UNSUPPORTED_BODY as QName :=
    QName("yi:UNSUPPORTED_BODY");

declare %private function yi:parse-sequence(
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

declare %an:sequential %private function yi:send-request(
    $name as string,
    $path as string) as item* {
    yi:send-request($name, $path, "POST")
};

declare %an:sequential %private function yi:send-request(
    $name as string,
    $path as string,
    $method as string) as item* {
    yi:send-request($name, $path, $method, ())
};

declare %an:sequential %private function yi:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object?) as item* {
    yi:send-request($name, $path, $method, $query-parameters, ())
};

declare %an:sequential %private function yi:send-request(
    $name as string,
    $path as string,
    $method as string,
    $query-parameters as object?,
    $body as item?) as item* {
    yi:send-request($name, $path, $method, $query-parameters, $body, ())
};

declare %an:sequential %private function yi:send-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as item* {
    let $request :=
      yi:request($name, $path, $method, $query-parameters, $body, $headers)
    let $response := http:send-request($request)
    return yi:response($response)
};

declare %private function yi:send-deterministic-request(
      $name as string,
      $path as string) as object {
    yi:send-deterministic-request($name, $path, "GET")
};

declare %private function yi:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string) as object {
    yi:send-deterministic-request($name, $path, $method, ())
};

declare %private function yi:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?) as object {
    yi:send-deterministic-request($name, $path, $method, $query-parameters, ())
};

declare %private function yi:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?) as item* {
    yi:send-deterministic-request($name, $path, $method, $query-parameters, $body, ())
};

declare %private function yi:send-deterministic-request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as item* {
    let $request :=
      yi:request($name, $path, $method, $query-parameters, $body, $headers)
    let $response :=
      http:send-deterministic-request($request)
    return trace(yi:response($response), "response")
};

declare %private function yi:response(
    $response as object
) as item* {
    switch($response.status)
    case 200
    case 204
        return
        let $media := $response.body("media-type")
        return
            if(contains($media, "json")) then
                parse-json(string($response.body.content))
            else if($response.multipart) then
                yi:parse-sequence($response.multipart.parts[])
            else
                $response.body.content
       case 400 return error(QName("yi:BAD_REQUEST"), "Unsupported or invalid parameters, or missing required parameters.", $response)
       case 401 return error(QName("yi:UNAUTHORIZED"), "User is not authorized.", $response)
       case 403 return error(QName("yi:FORBIDDEN"), "User does not have access to this resource.", $response)
       case 404 return error(QName("yi:NOT_FOUND"), "No matching pattern for incoming URI.", $response)
       case 405 return error(QName("yi:METHOD_NOT_ALLOWED"), "The service does not support the HTTP method used by the client.", $response)
       case 406 return error(QName("yi:UNACCEPTABLE_TYPE"), "Unable to provide content type matching the client's Accept header.", $response)
       case 412 return error(QName("yi:PRECONDITION_FAILED"), "A non-syntactic part of the request was rejected. For example, an empty POST or PUT body.", $response)
       case 415 return error(QName("yi:UNSUPPORTED_MEDIA_TYPE"), "A PUT or POST payload cannot be accepted.", $response)
       default return error(QName("yi:UNKNOWN_ERROR"), "Unknown error (status " || $response.status || ")", $response)
};

declare %private function yi:request(
      $name as string,
      $path as string,
      $method as string,
      $query-parameters as object?,
      $body as item?,
      $headers as object?) as object {
    let $credentials := credentials:credentials($yi:category, $name)
    return {|
        {
            href: "http://" ||
                  $credentials.hostname || ":" ||
                  $credentials.port || $yi:BASE_PATH[not starts-with($path, $yi:BASE_PATH)] ||
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
            headers: if($headers) then $headers else {} (:),
            authentication: {
                username: $credentials.username,
                password: $credentials.password,
                "auth-method": "Digest"
            }:)
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
                          default return error($yi:UNSUPPORTED_BODY)
                    |}
                }
            else ()
        |}
    |}
};

declare %an:sequential function yi:create-repository(
    $connection as string,
    $repository-name as string)
as ()
{
    yi:send-request($connection, "/repositories", "POST", {}, { repositoryName: $repository-name });
};

declare function yi:repositories(
    $connection as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories", "GET").result[]
};

declare function yi:repository(
    $connection as string,
    $repository as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository, "GET").result[]
};

declare function yi:metadata(
    $connection as string,
    $repository as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/metadata", "GET").result[]
};

declare function yi:metatype(
    $connection as string,
    $repository as string,
    $metatype as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/metadata/"||$metatype, "GET").result[]
};

declare function yi:indexes(
    $connection as string,
    $repository as string,
    $metatype as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/metadata/"||$metatype||"/indexes", "GET").result[]
};

declare function yi:branches(
    $connection as string,
    $repository as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/branches", "GET").result[]
};

declare function yi:branch(
    $connection as string,
    $repository as string,
    $branch as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/branches/"||$branch, "GET").result[]
};

declare function yi:entities(
    $connection as string,
    $repository as string,
    $branch as string,
    $metatype as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/branches/"||$branch||"/"||$metatype, "GET").result[]
};

declare function yi:entity(
    $connection as string,
    $repository as string,
    $branch as string,
    $metatype as string,
    $oid as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/branches/"||$branch||"/"||$metatype||"/"||$oid, "GET").result[]
};

declare function yi:query(
    $connection as string,
    $repository as string,
    $branch as string,
    $query as string)
as object*
{
    yi:send-deterministic-request($connection, "/repositories/"||$repository||"/branches/"||$branch||"/query/"||$query, "GET").result[]
};

declare function yi:document(
    $name as string,
    $uri as string)
as object
{
    yi:send-deterministic-request($name, "/documents", "GET", { uri: $uri })
};

declare function yi:qbe(
    $name as string,
    $collection as string)
as object*
{
    yi:qbe($name, $collection, {})
};

declare function yi:qbe(
    $name as string,
    $collection as string,
    $query as object)
as object*
{
    yi:qbe($name, $collection, $query, 1, 10000)
};

declare function yi:qbe(
    $name as string,
    $collection as string,
    $query as object,
    $offset as integer,
    $limit as integer)
as object*
{
    let $response := yi:send-deterministic-request(
        $name,
        "/qbe",
        "POST",
        {
            collection: $collection,
            start: $offset,
            pageLength: $limit
        },
        {
            "$query" : $query
        },
        {
          Accept:
            "multipart/mixed; boundary=DEFAULT_BOUNDARY_14201231297125830186"
        }
    )
    return $response
};

declare function yi:count(
    $name as string,
    $collection as string
) as integer {
    yi:simple-query($name, "count(collection(\"" || $collection || "\"))")
};

declare function yi:simple-query(
    $name as string,
    $query as string
) as item* {
    yi:send-deterministic-request($name, "/eval", "POST", { pageLength: 10000 }, "xquery=" || $query, { "Content-Type": "application/x-www-form-urlencoded" })
};

declare %an:sequential function yi:query(
    $name as string,
    $query as string
) as item* {
    yi:send-request($name, "/eval", "POST", { pageLength: 10000 }, "xquery=" || $query, { "Content-Type": "application/x-www-form-urlencoded" })
};
