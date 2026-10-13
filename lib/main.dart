import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/providers/notification_provider.dart';
import 'package:goblink_park/providers/theme_provider.dart';
import 'package:goblink_park/theme/app_theme.dart';
import 'package:goblink_park/services/push_notification_service.dart';
import 'package:goblink_park/services/sync_service.dart';
import 'package:goblink_park/screens/main_home.dart';
import 'package:goblink_park/screens/splash_screen/splash_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('isDarkMode') ?? prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Inicializar servicio de notificaciones push y sincronización offline en paralelo
  PushNotificationService.initialize();
  SyncService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(initialIsDark: isDark)),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Goblin Park',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
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
