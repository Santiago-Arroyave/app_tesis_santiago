import 'dart:async';
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
                  width: 150,
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
}
