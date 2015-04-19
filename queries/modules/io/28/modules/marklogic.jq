module namespace ml = "http://28.io/modules/marklogic";

import module namespace credentials = "http://www.28msec.com/modules/credentials";
import module namespace http = "http://zorba.io/modules/http-client";

declare %private variable $ml:credentials-category as string := "MarkLogic";

declare function ml:put-document($credentials as object, $uri as string, $document as object)
as empty-sequence()
{
  
};

declare function ml:get-document(){

};
