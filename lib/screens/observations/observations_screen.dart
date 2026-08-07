/*import 'package:flutter/material.dart';
//import 'package:app_tesis/screens/observations/create_observations.dart';
//import 'package:app_tesis/screens/observations/my_observations.dart';
import 'package:app_tesis/screens/observations/observation_map_screen.dart';

class ObservationsScreen extends StatelessWidget {
  const ObservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Observaciones")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              child: const Text("Crear Observación"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ObservationMapScreen()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Ver mis observaciones"),
              onPressed: () => Navigator.push(
                context,
                //MaterialPageRoute(builder: (_) => const MyObservationsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/