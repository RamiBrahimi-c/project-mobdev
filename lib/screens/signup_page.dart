import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final service = AuthService();

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final confirmEmail = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  DateTime? dob;

  void signup() async {
    if (firstName.text.isEmpty || lastName.text.isEmpty || email.text.isEmpty) {
      showMsg("Insert all fields");
      return;
    }

    if (password.text.length < 6) {
      showMsg("Weak Password, use at least 6 characters");
      return;
    }

    if (dob == null) {
      showMsg("Select date of birth");
      return;
    }

    if (!service.isAtLeast13(dob!)) {
      showMsg("Must be 13+");
      return;
    }

    if (email.text != confirmEmail.text) {
      showMsg("Emails do not match");
      return;
    }

    if (password.text != confirmPassword.text) {
      showMsg("Passwords do not match");
      return;
    }

    try {
      await service.signup(
        firstName: firstName.text,
        lastName: lastName.text,
        dob: dob!,
        email: email.text,
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showMsg(e.message ?? "Signup failed");
      return;
    } catch (_) {
      if (!mounted) return;
      showMsg("An unexpected error occurred");
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => dob = picked);
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    confirmEmail.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Signup")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(controller: firstName, decoration: const InputDecoration(labelText: "First Name")),
            TextField(controller: lastName, decoration: const InputDecoration(labelText: "Last Name")),
            ListTile(
              title: Text(dob == null ? "Date of birth" : dob.toString().split(" ")[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickDate,
            ),
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: confirmEmail, decoration: const InputDecoration(labelText: "Confirm Email")),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            TextField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: "Confirm Password")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: signup, child: const Text("Create Account")),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Login")),
              ],
            )
          ],
        ),
      ),
    );
  }
}
