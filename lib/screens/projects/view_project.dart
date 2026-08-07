import 'package:flutter/material.dart';

class ViewProjectScreen extends StatelessWidget {
  const ViewProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Proyectos creados")),
      body: ListView(
        children: const [
          ListTile(title: Text("Proyecto Ambiental 1")),
          ListTile(title: Text("Proyecto Agua Limpia")),
        ],
      ),
    );
  }
}