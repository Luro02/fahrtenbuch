import 'package:flutter/material.dart';

import 'pages/login.dart';
import 'pages/home.dart';
import 'constants.dart';

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
        brightness: Brightness.light,
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
