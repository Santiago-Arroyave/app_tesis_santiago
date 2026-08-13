import 'package:flutter/material.dart';
import 'package:app_tesis/screens/main_map/home_map_screen.dart';
//import 'package:app_tesis/screens/observations/observations_screen.dart';
import 'package:app_tesis/screens/projects/project_screen.dart';
import 'package:app_tesis/screens/profile/profile_screen.dart';
//import 'package:app_tesis/screens/report_map/report_maps.dart';
//import 'package:app_tesis/screens/report_map/report_map_service.dart';
import 'package:app_tesis/screens/observations/my_observations_screen.dart';
import 'package:app_tesis/screens/observations/observation_map_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeMapScreen(),
    ProjectScreen(),
    ObservationMapScreen(),
    MyObservationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 ESTO mantiene las pantallas vivas (como apps reales)
      body: IndexedStack(index: _currentIndex, children: _screens),

      // 👇 MENÚ INFERIOR SIEMPRE VISIBLE
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color.fromARGB(255, 7, 83, 11),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Inicio.png',
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
            activeIcon: Image.asset(
              'assets/images/Inicio.png',
              width: 24,
              height: 24,
              color: const Color.fromARGB(255, 7, 83, 11),
            ),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Hacer reporte.png',
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
            activeIcon: Image.asset(
              'assets/images/Hacer reporte.png',
              width: 24,
              height: 24,
              color: const Color.fromARGB(255, 7, 83, 11),
            ),
            label: 'Proyectos',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/mapa.png',
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
            activeIcon: Image.asset(
              'assets/images/mapa.png',
              width: 24,
              height: 24,
              color: const Color.fromARGB(255, 7, 83, 11),
            ),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Registro Reportes.png',
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
            activeIcon: Image.asset(
              'assets/images/Registro Reportes.png',
              width: 24,
              height: 24,
              color: const Color.fromARGB(255, 7, 83, 11),
            ),
            label: 'Ver Reportes',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/usuario.png',
              width: 24,
              height: 24,
              color: Colors.grey,
            ),
            activeIcon: Image.asset(
              'assets/images/usuario.png',
              width: 24,
              height: 24,
              color: const Color.fromARGB(255, 7, 83, 11),
            ),
            label: 'Perfil',
          ),
        ],
      ),
      /*bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home), // 0
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work), // 1 → Project
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_red_eye), // 2 → Observations
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map), // 3 → ReportMap
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // 4 → Profile
            label: "",
          ),
        ],
        /*items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.file_present),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "",
          ),
        ],*/
      ),*/
    );
  }
}
