import 'package:flutter/material.dart';
import 'package:goblink_park/screens/report_map/view_report.dart';

class ReportMapsScreen extends StatelessWidget {
  const ReportMapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes")),
      body: Center(
        child: ElevatedButton(
          child: const Text("Ver reportes"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ViewReportScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}