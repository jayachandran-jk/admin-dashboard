import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC_WZgd5rptD8s0-9UctRM2WmwRXsfI374",
      authDomain: "civichero-480a3.firebaseapp.com",
      databaseURL: "https://civichero-480a3-default-rtdb.asia-southeast1.firebasedatabase.app",
      projectId: "civichero-480a3",
      storageBucket: "civichero-480a3.firebasestorage.app",
      messagingSenderId: "727957080527",
      appId: "1:727957080527:web:4c113159d36a3f0540eaba",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<DataService>(create: (_) => DataService()),
      ],
      child: MaterialApp(
        title: 'CivicHero Admin',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}
