import 'package:flutter/material.dart';
import 'package:goblink_park/screens/report_map/result_report.dart';


class FilterCategoryScreen extends StatelessWidget {
  const FilterCategoryScreen({super.key});

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
      appBar: AppBar(title: const Text("Seleccionar categoría")),
      body: ListView.builder(
        itemCount: categorys.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(categorys[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ResultReportScreen(category: categorys[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}