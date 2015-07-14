import module namespace yi = "http://28.io/modules/yidb";
import module namespace credentials =
    "http://www.28msec.com/modules/credentials";

declare %private variable $BASE_PATH as string := "/cms";

let $credentials := credentials:credentials("YiDB", "mydb")
let $path := "/repositories"
let $query-parameters := {}
let $method := "GET"
let $headers := ()
return {|
		{
				href: "http://" ||
							$credentials.hostname || ":" ||
							$credentials.port || $BASE_PATH[not starts-with($path, $BASE_PATH)] ||
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

|}(:)
yi:repositories("mydb");:)
