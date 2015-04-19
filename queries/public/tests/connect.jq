import module namespace ml = "http://28.io/modules/marklogic";

declare variable $credentials := {
  url: "localhost:8003",
  username: "test",
  password: "foobar"
};

ml:put-document($credentials, "/example/recipe.json", {
    recipe: "Apple pie",
    fromScratch: true,
    ingredients: "The Universe"
});
ml:get-document($credentials, "/example/recipe.json")
