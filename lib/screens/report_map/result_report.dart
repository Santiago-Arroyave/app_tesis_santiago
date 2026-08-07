import 'package:flutter/material.dart';

class ResultReportScreen extends StatelessWidget {
  final String category;

  const ResultReportScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Resultados: $category")),
      body: ListView(
        children: [
          ListTile(title: Text("Reporte de $category 1")),
          ListTile(title: Text("Reporte de $category 2")),
        ],
      ),
    );
  }
}