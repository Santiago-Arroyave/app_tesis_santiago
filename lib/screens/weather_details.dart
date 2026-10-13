import 'package:flutter/material.dart';
//import 'package:recipe_book/models/recipe_model.dart';
//import 'package:recipe_book/providers/recipes_provider.dart';
import 'package:goblink_park/providers/weather_provider.dart';
import 'package:goblink_park/models/weather_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class WeatherDetails extends StatefulWidget {
  final Weather weatherData;
  const WeatherDetails({super.key, required this.weatherData});

  @override
  State<WeatherDetails> createState() => _WeatherDetailState();
}

class _WeatherDetailState extends State<WeatherDetails>
    with SingleTickerProviderStateMixin {
  bool isFavorite = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 1.5).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _controller.reverse();
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isFavorite = Provider.of<WeatherProvider>(
      context,
      listen: false,
    ).favoriteWeather.contains(widget.weatherData);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.weatherData.name,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Provider.of<WeatherProvider>(
                context,
                listen: false,
              ).toggleFavoriteStatus(widget.weatherData);

              setState(() {
                isFavorite = !isFavorite;
              });

              _controller.forward(); // 🔥 opcional para animación
            },
            icon: ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            CachedNetworkImage(
              imageUrl: widget.weatherData.img_link,
              memCacheWidth: 600,
              placeholder: (context, url) => Container(height: 150, color: Colors.grey.shade200),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(widget.weatherData.name),
            SizedBox(height: 8),
            Text("By ${widget.weatherData.author}"),
            SizedBox(height: 8),
            Text('Recipes steps:'),
            for (var step in widget.weatherData.recipeSteps) Text("- $step"),
          ],
        ),
      ),
    );
  }
}

