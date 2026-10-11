//import 'package:app_tesis/screens/login_screen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/screens/main_home.dart';
import 'package:goblink_park/screens/splash_screen/splash_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, child) {
        return MaterialApp(
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF1E5E3A),
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color.fromARGB(255, 7, 83, 11),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF1E5E3A),
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1E5E3A),
              secondary: Color(0xFF2E7D32),
              surface: Color(0xFF1E1E1E),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Color(0xFF4CAF50),
            ),
          ),
          debugShowCheckedModeBanner: false,
          title: 'GoblinPark App',
          home: SplashScreen(),
        );
      },
    );
  }
}

class WeatherTime extends StatelessWidget {
  const WeatherTime({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Menu Principal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 7, 83, 11),
      ),
      body: MainHome(),
    );
  }
}

/*class WeatherTime extends StatelessWidget {
  const WeatherTime({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('Weather', style: TextStyle(color: Colors.white)),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            tabs: [Tab(icon: Icon(Icons.home), text: 'Menu Principal')],
          ),
        ),
        //body: const TabBarView(children: [MainHome(),]),
        body: const TabBarView(children: [Center(child: Text("SI FUNCIONA"))]),
      ),
    );
  }
}*/
