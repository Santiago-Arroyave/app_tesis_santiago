import 'package:flutter/material.dart';
import 'package:goblink_park/screens/projects/state_application.dart';

class ApplicationProjectScreeen extends StatelessWidget {
  const ApplicationProjectScreeen({super.key});

  final List<String> proyectos = const [
    "Proyecto Ambiental 1",
    "Proyecto Agua Limpia",
    "Proyecto Aire Puro"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unirse a Proyecto")),
      body: ListView.builder(
        itemCount: proyectos.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(proyectos[index]),
            trailing: ElevatedButton(
              child: const Text("Solicitar"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StateApplicationScreen(proyecto: proyectos[index], aceptado: true,),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}