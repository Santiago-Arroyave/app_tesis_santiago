import 'dart:async';
import 'package:goblink_park/screens/login_screen/login_screen.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/main_map/main_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Mantener la duración actual del Splash
    await Future.delayed(const Duration(seconds: 8));

    if (!mounted) return;

    // =====================================================
    // COMPROBAR SI EXISTE UNA SESIÓN GUARDADA
    // =====================================================
    final token = await AuthService.getToken();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // ===================================================
      // HAY SESIÓN → IR AL MENÚ PRINCIPAL
      // ===================================================
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      // ===================================================
      // NO HAY SESIÓN → IR AL LOGIN
      // ===================================================
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2319),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Fondo de frailejones
          Image.asset(
            'assets/images/Fondo-Login.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF0D2319),
            ),
          ),

          // 🌲 Overlay / Degradado en verde bosque oscuro profundo (#0d2319 / #143324)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D2319).withValues(alpha: 0.78),
                  const Color(0xFF143324).withValues(alpha: 0.75),
                  const Color(0xFF0D2319).withValues(alpha: 0.85),
                ],
              ),
            ),
          ),

          // 🌿 Composición central: Logo circular blanco + Título + Subtítulo
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/Logo Blanco.png',
                    width: 155,
                    height: 155,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'GoblinPark',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitoreo del Páramo del Duende',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔄 Pie de pantalla: Spinner sutil + "Preparando la aplicación..."
          Positioned(
            bottom: 42,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparando la aplicación...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/*import 'dart:async';
import 'package:app_tesis/screens/login_screen/login_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 8), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Fondo
          Image.asset(
            'assets/images/Fondo.jpeg', // tu imagen de fondo
            fit: BoxFit.cover,
          ),

          // 🌑 Capa oscura (para que el logo resalte)
          Container(color: Colors.black.withOpacity(0.4)),

          // 🌿 Logo centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/Logo Blanco.png', // tu logo
                  width: 200,
                ),
                SizedBox(height: 20),
                Text(
                  "GoblinPark",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 🔄 Loader abajo 
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}*/
