import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetPasswordPage extends StatelessWidget {
  ResetPasswordPage({super.key});
  final emailController = TextEditingController();
  final service = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Enter your Email"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await service.resetPassword(emailController.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reset email sent! Check your inbox.")),
                );
                Navigator.pop(context);
              },
              child: const Text("Send Reset Link"),
            ),
          ],
        ),
      ),
    );
  }
}