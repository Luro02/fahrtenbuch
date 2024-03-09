import 'package:flutter/material.dart';

import 'package:fahrtenbuch/pages/home.dart';
import 'package:fahrtenbuch/pages/login.dart';
import 'package:fahrtenbuch/constants.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fahrtenbuch',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: ColorSeed.baseColor.color,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: ColorSeed.baseColor.color,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: LoginPage(
        onLoginSuccess: (context) => const Home(),
      ),
    );
  }
}
