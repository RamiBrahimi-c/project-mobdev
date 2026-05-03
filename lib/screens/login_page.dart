import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup_page.dart';
import '../services/auth_service.dart';
import 'reset_password.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginEmail = TextEditingController();
  final loginPwd = TextEditingController();
  final service = AuthService();

  void login() async {
    try {
      await service.login(loginEmail.text, loginPwd.text);
    } on FirebaseAuthException catch (e) {
      // Show a real message instead of crashing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Auth Failed"))
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred"))
      );
    }
  }

  @override
  void dispose() {
    loginEmail.dispose();
    loginPwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(

          children: [
            TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage()));
                },
                child: const Text("Forgot Password?"),
              ),
            TextField(controller: loginEmail, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: loginPwd, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text("Login")),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't you have an account?"),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                  child: const Text("Signup"),
                ),
              ],
            )
          ],
          
        ),
      ),
    );
  }
}
