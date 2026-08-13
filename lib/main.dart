//import 'package:app_tesis/screens/login_screen/login_screen.dart';
import 'package:flutter/material.dart';
//import 'package:app_tesis/providers/weather_provider.dart';
//import 'package:app_tesis/screens/weather_observations.dart';
//import 'package:app_tesis/screens/home_screen.dart';
//import 'package:provider/provider.dart';
//import 'package:flutter_localizations/flutter_localizations.dart';
//import 'package:app_tesis/l10n/app_localizations.dart';
import 'package:app_tesis/screens/main_home.dart';
import 'package:app_tesis/screens/splash_screen/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color.fromARGB(255, 7, 83, 11),
        ),
      ),
      //providers: [ChangeNotifierProvider(create: (_) => WeatherProvider())],
      //child: const MaterialApp(
      /*localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],*/
      debugShowCheckedModeBanner: false,
      title: 'Hola mundo',
      home: SplashScreen(),
      // ),
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
