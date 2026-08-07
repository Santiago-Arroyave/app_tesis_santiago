class Weather{
  int id;
  String name;
  String author;
  String img_link;
  List<String> recipeSteps;

  Weather({
    required this.id,
    required this.name,
    required this.author,
    required this.img_link,
    required this.recipeSteps
  });

  factory Weather.fromJSON(Map<String, dynamic> json){
    return Weather(
      id: json['id'],
      name: json['name'], 
      author: json['author'], 
      img_link: json['image_link'], 
      recipeSteps: List<String>.from(json['recipe']));
  }

  Map<String, dynamic> toJson(){
    return {
      'name': name,
      'author': author,
      'image_link': img_link,
      'recipe': recipeSteps
    };
  }

  @override
  String toString(){
    return 'Recipe{name: $name, author: $author, image_link: $img_link, recipe: $recipeSteps}';
  }

}