module namespace http = "http://28.io/modules/http-client-wrapper";

import module namespace base64 = "http://zorba.io/modules/base64";

import module namespace http-impl = "http://zorba.io/modules/http-client";

declare namespace ver = "http://zorba.io/options/versioning";

declare variable $http:default-boundary := "multipart/mixed; boundary=DEFAULT_BOUNDARY_14201231297125830186";

declare %an:sequential function http:send-request($request as object) as object
{
    let $response := http-impl:send-request($request)
    let $response := http:response($response)
    return $response
};

declare %an:nondeterministic function http:send-nondeterministic-request($request as object) as object
{
    let $response := http-impl:send-nondeterministic-request($request)
    let $response := http:response($response)
    return $response
};

declare function http:send-deterministic-request($request as object) as object
{
    let $response := http-impl:send-deterministic-request($request)
    let $response := http:response($response)
    return $response
};

declare %private function http:response($response as object) as object {
    let $media := $response.body("media-type")
    return
        if(contains($media, "multipart")) then
            copy $nr := $response
            modify (
                delete json $nr.body,
                insert json http:parse-multipart($nr.body.content, $response.headers("Content-Type")) into $nr
            )
            return $nr
        else
            $response
};

declare %private function http:parse-multipart($body as base64Binary, $content-type as string) as object {
    let $body := base64:decode($body)
    let $content-type :=
        if(contains($content-type, "multipart")) then
            $content-type
        else
            $http:default-boundary
    let $values := tokenize($content-type, ";") !
                    {|
                        let $tokens := tokenize($$, "=")
                        return { fn:normalize-space($tokens[1]): $tokens[2] }
                    |}
    let $values := $values
    let $boundary := "--" || $values("boundary")
    let $parts :=
        let $parts := tokenize($body, $boundary)
        for $part in $parts
        let $part := substring(substring($part, 1, string-length($part) - 2), 2)
        where $part ne ""
        let $tokens  := tokenize($part, "\r\n\r\n")
        let $headers := tokenize(substring($tokens[1], 2), "\r\n")
        let $headers :=
            for $header in $headers
            let $tokens := tokenize($header, ": ")
            let $name := $tokens[1]
            let $value := string-join(subsequence($tokens, 2), ":")
            return { $name: $value }
        where exists($headers)
        return {
            headers: {| $headers |},
            body: {
                "media-type": $headers("Content-Type"),
                content: if(contains($headers("Content-Type"), "json")) then
                    parse-json($tokens[2])
                else
                    $tokens[2]
            }
        }
    return {
        multipart: {
            boundary: $boundary,
            parts: [$parts]
        }
    }
};
