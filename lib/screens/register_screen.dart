// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import '../core/config/app_config.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false; // To show a loading spinner

  // The function that actually talks to Spring Boot!
  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          // Add firstName, lastName, etc., here if your backend requires them!
        }),
      );

      if (response.statusCode == 200) {
        // Success! Show a popup message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        // Failed! Show the error.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red),
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            
            // Show a loading spinner if registering, otherwise show the button
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Register', style: TextStyle(fontSize: 18)),
                ),
          ],
        ),
      ),
    );
  }
}