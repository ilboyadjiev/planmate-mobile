// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'home_screen.dart';
import '../core/config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _loginUser() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _emailController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        final username = responseData['username'] ?? 'User';
        final firstName = responseData['firstName'] ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', responseData['accessToken']);
        await prefs.setString('refresh_token', responseData['refreshToken']);
        await prefs.setString('username', username);
        if (firstName != null) {
          await prefs.setString('firstName', firstName);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(username: username, firstName: firstName),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: ${response.body}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planmate Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 32),
            
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _passwordController,
              obscureText: true, 
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 32),
            
            // Show loading spinner OR the Login Button
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _loginUser, // Connected to our new function!
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50), 
                  ),
                  child: const Text('Login', style: TextStyle(fontSize: 18)),
                ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const Text(
                "Don't have an account? Register here",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}