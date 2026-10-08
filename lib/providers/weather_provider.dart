import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:goblink_park/models/weather_model.dart';
import 'package:http/http.dart' as http;

class WeatherProvider extends ChangeNotifier{
  bool isLoading = false;
  List<Weather> weathers = [];
  List<Weather> favoriteWeather = [];

  Future<void> fetchWeather() async {
    isLoading = true;
    notifyListeners();

    final url = Uri.parse('http://10.0.2.2:8000/recipes/');
    try{
    final response = await http.get(url);
    if (response.statusCode == 200){
        final data = jsonDecode(response.body);
        weathers = List<Weather>.from(data['recipes']
        .map((recipe) => Weather.fromJSON(recipe)));
    }else{
      print('Error ${response.statusCode}');
      weathers = [];
    }
    } catch (e){
      print('Error en la solicitud: $e' );
      weathers = [];
    }finally{
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavoriteStatus(Weather recipe) async{
    final isFavorite = favoriteWeather.contains(recipe);

    try{
      final url = Uri.parse('http://10.0.2.2:8000/favorites/');
      final response = isFavorite ? 
        await http.delete(url, body: json.encode({"id": recipe.id}))
        : await http.post(url, body: json.encode(recipe.toJson()));

        if (response.statusCode == 200) {
          if (isFavorite) {
            favoriteWeather.remove(recipe);
          }else{
            favoriteWeather.add(recipe);
          }
          notifyListeners();
        }else{
          throw Exception('Failed to Update favorite recipes');
        }
    }catch (e) {
        print('Error updating favorite status $e');
    }
  }
}