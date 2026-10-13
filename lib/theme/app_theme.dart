import 'package:flutter/material.dart';

class AppTheme {
  // Tema Claro Oficial
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF1E5E3A),
    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1E5E3A),
      secondary: Color(0xFF2E7D32),
      surface: Colors.white,
      error: Color(0xFFE63946),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF0F3A22),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F3A22),
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF1E5E3A),
      unselectedItemColor: Color(0xFF9CA3AF),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E5E3A), width: 1.5),
      ),
    ),
  );

  // Tema Oscuro Oficial para GoblinPark
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF1B4332), // Verde páramo profundo
    scaffoldBackgroundColor: const Color(0xFF121814), // Fondo oscuro con tinte verdoso neutro
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF52B788),
      secondary: Color(0xFF74C69D),
      surface: Color(0xFF1A231E), // Tarjetas y contenedores oscuros
      error: Color(0xFFE63946),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Color(0xFFE8F5E9), // Texto legible claro
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1A231E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121814),
      foregroundColor: Color(0xFFE8F5E9),
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A231E),
      selectedItemColor: Color(0xFF52B788),
      unselectedItemColor: Color(0xFF9CA3AF),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF222E27),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF52B788), width: 1.5),
      ),
    ),
  );
}
