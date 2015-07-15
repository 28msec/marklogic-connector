import module namespace ml = "http://28.io/modules/marklogic";

ml:put-document("xbrl", "/example/recipe.json", {
    recipe: "Apple pie",
    fromScratch: true,
    ingredients: "The Universe"
});
ml:document("xbrl", "/example/recipe.json")
