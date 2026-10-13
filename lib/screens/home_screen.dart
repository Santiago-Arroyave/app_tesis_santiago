//import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:goblink_park/providers/weather_provider.dart';
//import 'package:recipe_book/models/recipe_model.dart';
//import 'package:recipe_book/providers/recipes_provider.dart';
import 'package:goblink_park/screens/weather_details.dart';
import 'package:cached_network_image/cached_network_image.dart';
//import 'package:http/http.dart' as http;
import 'package:goblink_park/l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    weatherProvider.fetchWeather();

    return Scaffold(
      body: Consumer<WeatherProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          else if (provider.weathers.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noRecipes),);
          } else {
            return ListView.builder(
              itemCount: provider.weathers.length,
              itemBuilder: (context, index) {
                return _recipesCard(context, provider.weathers[index]);
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _showBottom(context);
        },
      ),
    );
  }

  Future<void> _showBottom(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        height: 500,
        color: Colors.white,
        child: RecipeForm(),
      ),
    );
  }

  Widget _recipesCard(BuildContext context, dynamic recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeatherDetails(weatherData: recipe),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 125,
          child: Card(
            child: Row(
              children: <Widget>[
                SizedBox(
                  height: 125,
                  width: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: recipe.img_link,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      placeholder: (context, url) => Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 26),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe.name,
                        style: TextStyle(fontSize: 16, fontFamily: 'Quicksand'),
                      ),
                      SizedBox(height: 4),
                      Container(height: 2, width: 75, color: Colors.orange),
                      Text(
                        'By ${recipe.author}',
                        style: TextStyle(fontSize: 16, fontFamily: 'Quicksand'),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeForm extends StatefulWidget {
  const RecipeForm({super.key});

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _recipeName = TextEditingController();
  final TextEditingController _recipeAuthor = TextEditingController();
  final TextEditingController _recipeImage = TextEditingController();
  final TextEditingController _recipeDescription = TextEditingController();

  @override
  void dispose() {
    _recipeName.dispose();
    _recipeAuthor.dispose();
    _recipeImage.dispose();
    _recipeDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Recipe',
              style: TextStyle(color: Colors.orange, fontSize: 24),
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _recipeName,
              label: 'Recipe Name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese un nombre';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _recipeAuthor,
              label: 'Author',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese un nombre';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _recipeImage,
              label: 'Image URL',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese un nombre';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            _buildTextField(
              maxLines: 3,
              controller: _recipeDescription,
              label: 'Recipe',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese un nombre';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Guardar Receta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Quicksand', color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }
}
