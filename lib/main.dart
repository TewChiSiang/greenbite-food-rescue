import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart'; 

void main() async {
  // 1. Ensure Flutter is fully initialized before starting Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase WITH WEB OPTIONS
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
  
  // 3. Run the GreenBite App
  runApp(const GreenBiteApp());
}

class GreenBiteApp extends StatelessWidget {
  const GreenBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Start the app on the Login Screen
      home: const LoginScreen(),
    );
  }
}