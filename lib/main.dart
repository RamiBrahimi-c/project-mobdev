import 'package:final_final/services/audio_manager.dart';
import 'package:final_final/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your other files - Make sure these paths match your folder
import 'services/auth_service.dart'; 
import 'screens/login_page.dart';
import 'screens/biometric_screen.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_chart/fl_chart.dart'; // Make sure this is in pubspec.yaml
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/player_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Deep Midnight Blue
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
    ),
    home: const AppStartGate(),
  ));
}

class AppStartGate extends StatefulWidget {
  const AppStartGate({super.key});
  @override
  State<AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<AppStartGate> {
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    // LOCK: If not unlocked, show ONLY the Biometric Screen. 
    // This stops Firebase from even trying to run.
    if (!_isUnlocked) {
      return BiometricScreen(onSuccess: () {
        setState(() => _isUnlocked = true);
      });
    }

    // UNLOCK: Now we let Firebase take over.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) return const LoginPage();
        return const ProfilePage();
      },
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _monthlyGoal = 20;
  final List<double> _dailyMinutes = [45, 120, 30, 90, 60, 15, 100]; 

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _monthlyGoal = prefs.getInt('monthly_goal') ?? 20);
  }

  _updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthly_goal', newGoal);
    setState(() => _monthlyGoal = newGoal);
  }

  String _getTotalTime() {
    double totalMinutes = _dailyMinutes.reduce((a, b) => a + b);
    int hours = (totalMinutes / 60).floor();
    int minutes = (totalMinutes % 60).toInt();
    return "$hours h ${minutes} m";
  }

  void _secureDelete(DocumentReference docRef) async {
    bool authenticated = await BiometricService.authenticate();
    if (authenticated) {
      await docRef.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Midnight Background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("Stats", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () { AudioManager.stopAll(); AuthService().logout(); },
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent)
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: AuthService().getProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {"firstName": "Guest", "lastName": ""};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sleek Welcome Section
                Text("Hello,", style: TextStyle(color: Colors.blueGrey[300], fontSize: 18)),
                Text("${data['firstName']} ${data['lastName']}", 
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // 2. Time Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), // Slate Card
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.waves, color: Colors.blueAccent),
                      const SizedBox(width: 15),
                      Text("Total Time: ${_getTotalTime()}", 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

                const SizedBox(height: 35),
                const Text("Activity", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // 3. Neon Histogram
                Container(
                  height: 180,
                  padding: const EdgeInsets.only(top: 20, right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: _dailyMinutes.asMap().entries.map((e) => 
                        BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(
                            toY: e.value, 
                            color: Colors.blueAccent, 
                            width: 12, 
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(show: true, toY: 150, color: const Color(0xFF334155))
                          )
                        ])
                      ).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                // 4. Goal Card
                _buildGoalSection(),

                const SizedBox(height: 35),
                // 5. High-Contrast Action Button
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Pop against dark background
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerPage())),
                    child: const Text("OPEN LIBRARY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 35),
                const Text("Favorites", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildFavoritesList(user.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalSection() {
    double progress = (_dailyMinutes.reduce((a, b) => a + b) / 60) / _monthlyGoal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Goal", style: TextStyle(color: Colors.white)),
              DropdownButton<int>(
                value: _monthlyGoal,
                dropdownColor: const Color(0xFF1E293B),
                underline: const SizedBox(),
                items: [10, 20, 30, 40].map((int val) => DropdownMenuItem(value: val, child: Text("$val hrs"))).toList(),
                onChanged: (val) => _updateGoal(val!),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFF334155),
            color: Colors.blueAccent,
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('favorites').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final fav = docs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                title: Text(fav['name'], style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.blueGrey),
                  onPressed: () => _secureDelete(fav.reference),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
