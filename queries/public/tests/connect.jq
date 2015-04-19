import module namespace ml = "http://28.io/modules/marklogic";

ml:put-document("test-ml", "/example/recipe.json", {
    recipe: "Apple pie",
    fromScratch: true,
    ingredients: "The Universe"
});
ml:get-document("test-ml", "/example/recipe.json")
