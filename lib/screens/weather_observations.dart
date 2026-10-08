import 'package:flutter/material.dart';
//import 'package:recipe_book/providers/recipes_provider.dart';
import 'package:provider/provider.dart';
//import 'package:recipe_book/screens/recipe_detail.dart';
//import 'package:recipe_book/models/recipe_model.dart';
//import 'package:recipe_book/l10n/app_localizations.dart';
import 'package:goblink_park/providers/weather_provider.dart';
import 'package:goblink_park/models/weather_model.dart';
import 'package:goblink_park/screens/weather_details.dart';
import 'package:goblink_park/l10n/app_localizations.dart';

class WeatherObservations extends StatelessWidget {
  const WeatherObservations({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          final favoritesWeather = weatherProvider.favoriteWeather;

          return favoritesWeather.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noRecipes))
              : ListView.builder(
                  itemCount: favoritesWeather.length,
                  itemBuilder: (context, index) {
                    final weather = favoritesWeather[index];
                    return favoritesWeatherCard(weather: weather);
                  },
                );
        },
      ),
    );
  }
}

class favoritesWeatherCard extends StatelessWidget {
  final Weather weather;
  const favoritesWeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeatherDetails(weatherData: weather),
          ),
        );
      },
      child: Semantics(
        label: 'Tarjeta de recetas',
        hint: 'Toca para ver detalle de receta ${weather.name}',
        child: Card(
          color: Colors.white,
          child: Column(children: [Text(weather.name), Text(weather.author)]),
        ),
      ),
    );
  }
}
