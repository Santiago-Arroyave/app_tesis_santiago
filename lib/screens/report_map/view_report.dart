import 'package:flutter/material.dart';
import 'package:goblink_park/screens/report_map/filter_report.dart';

class ViewReportScreen extends StatelessWidget {
  const ViewReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FilterCategoryScreen(),
                ),
              );
            },
            child: const Text("Filtrar por categoría"),
          ),

          const SizedBox(height: 20),

          // Lista simulada
          Expanded(
            child: ListView(
              children: const [
                ListTile(title: Text("Reporte 1 - Alta prioridad")),
                ListTile(title: Text("Reporte 2 - Baja prioridad")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}