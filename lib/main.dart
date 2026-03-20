import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/theme_extensions.dart';

void main() {
  runApp(const PlanmateApp());
}

// The root of your application
class PlanmateApp extends StatelessWidget {
  const PlanmateApp({super.key});

  static const Color neonOrange = Color(0xFFFF5F1F);

  // This function peeks into the phone's storage to see if a token exists
  Future<String?> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token != null) {
      return prefs.getString('username'); 
    }
    return null; 
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planmate',
      
      // --- LIGHT MODE ---
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: neonOrange,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: neonOrange,
          elevation: 1, 
        ),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          EventColors(
            myEvent: neonOrange,
            inviteEvent: Colors.purple,
            googleEvent: Colors.red,
            appleEvent: Colors.black,
            samsungEvent: Colors.cyan,
          ),
        ],
      ),

      // --- DARK MODE ---
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: neonOrange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: neonOrange,
          elevation: 1,
        ),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[
          EventColors(
            myEvent: neonOrange,
            inviteEvent: Colors.purple,
            googleEvent: Colors.redAccent,
            appleEvent: Colors.white,
            samsungEvent: Colors.cyanAccent,
          ),
        ],
      ),

      themeMode: ThemeMode.system, 
      home: FutureBuilder<String?>( // Change from bool to String?
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // If the snapshot has data (a username), they are logged in!
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(username: snapshot.data!); 
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}
