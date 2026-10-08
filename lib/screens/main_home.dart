import 'package:flutter/material.dart';
import 'package:goblink_park/screens/report_map/report_map_service.dart';
//mport 'package:goblink_park/screens/observations/observations_screen.dart';
import 'package:goblink_park/screens/projects/project_screen.dart';
import 'package:goblink_park/screens/profile/profile_screen.dart';
import 'package:goblink_park/screens/observations/my_observations_screen.dart';

class MainHome extends StatelessWidget {
  const MainHome({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, // 2 columnas tipo menú
      padding: const EdgeInsets.all(16),
      children: [
        _buildMenuItem(
          context,
          "Mapa de Reportes",
          Icons.map,
          const ReportMapScreen(),
        ),
        _buildMenuItem(
          context,
          "Observaciones",
          Icons.remove_red_eye,
          const MyObservationsScreen(),
        ),
        _buildMenuItem(
          context,
          "Proyectos",
          Icons.work,
          const ProjectScreen(),
        ),
        _buildMenuItem(
          context,
          "Perfil",
          Icons.person,
          const ProfileScreen(),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
      BuildContext context, String title, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.purple),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}