import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/OxygeneScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Vérifier si Firebase est déjà initialisé avant de l'initialiser
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Si Firebase est déjà initialisé, on ignore l'erreur
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized');
    } else {
      // Si c'est une autre erreur, on la relance
      rethrow;
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Système de supervision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const OxygeneScreen(),
    );
  }
}