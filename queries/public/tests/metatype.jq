import module namespace yi = "http://28.io/modules/yidb";

declare option rest:response "first-item";

{ "content-type" : "application/json"},
yi:metatype("mydb", "raptor-paas", "ApplicationServices")
