import module namespace ml = "http://28.io/modules/marklogic";

let $count := count(ml:qbe("xbrl", "entities", { }, 2 ,4))
return
  if($count eq 4) then
    true
  else
    error()
