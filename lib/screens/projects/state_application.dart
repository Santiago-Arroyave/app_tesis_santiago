import 'package:flutter/material.dart';

class StateApplicationScreen extends StatelessWidget {
  final String proyecto;
  final bool aceptado;

  const StateApplicationScreen({super.key, required this.proyecto, required this.aceptado});

  @override
  Widget build(BuildContext context) {
    // Simulación (luego lo conectas a backend)
    //bool aceptado = true;

    return Scaffold(
      appBar: AppBar(title: const Text("Estado de solicitud")),
      body: Center(
        child: aceptado
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  Text("Aceptado en $proyecto"),
                  const SizedBox(height: 20),
                  const Text("Añadido a mis proyectos"),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.hourglass_bottom,
                      color: Colors.orange, size: 80),
                  SizedBox(height: 20),
                  Text("Solicitud pendiente"),
                ],
              ),
      ),
    );
  }
}