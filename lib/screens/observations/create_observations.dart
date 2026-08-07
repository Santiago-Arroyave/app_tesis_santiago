/*import 'package:flutter/material.dart';
import 'package:app_tesis/screens/observations/observation_detail_screen.dart';

class CreateObservationsScreen extends StatelessWidget {
  const CreateObservationsScreen({super.key});

  final List<String> categorys = const [
    "Fauna",
    "Flora",
    "Agua",
    "Aire",
    "Suelo"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seleccionar Categoría")),
      body: ListView.builder(
        itemCount: categorys.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(categorys[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailObservationsScreen(
                    category: categorys[index],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}*/