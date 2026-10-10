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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Fondo unificado con el Login
          Image.asset('assets/images/Fondo-Login.png', fit: BoxFit.cover),

          // 🌑 Capa oscura de contraste
          Container(color: const Color(0x66000000)),

          // 🌿 Logo centrado y marca
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/Logo Blanco.png', width: 200),

                const SizedBox(height: 20),

                const Text(
                  "GoblinPark",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // 🔄 Loader sutil abajo
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
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
