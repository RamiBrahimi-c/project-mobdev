import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/audio_manager.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _audioPlayer = AudioManager.player;
  List _tracks = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  String _currentTitle = "Select a Surah";
  Set<String> _favoritedIds = {}; // Local track of hearts
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadFavorites();

    // Listeners for the Seek Bar (The Sound Bar)
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = (state == PlayerState.playing));
    });
  }

  // Load favorites so the hearts are red when you open the page
  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('favorites')
        .get();
    
    setState(() {
      _favoritedIds = snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters?language=en'));
      if (response.statusCode == 200) {
        setState(() {
          _tracks = json.decode(response.body)['chapters'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _play(int id, String name) async {
    setState(() => _currentTitle = name);
    String chapterId = id.toString().padLeft(3, '0');
    // Using a high-quality stable mp3 link
    String audioUrl = "https://server8.mp3quran.net/afs/$chapterId.mp3"; 
    await _audioPlayer.play(UrlSource(audioUrl));
  }

  String _formatDuration(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0").substring(3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Midnight
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Audio Library", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final chapter = _tracks[index];
                      final String chapterId = chapter['id'].toString();
                      bool isFav = _favoritedIds.contains(chapterId);

                      return ListTile(
                        leading: Text(chapterId, style: const TextStyle(color: Colors.blueGrey)),
                        title: Text(chapter['name_simple'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        subtitle: Text(chapter['translated_name']['name'], style: const TextStyle(color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, 
                                         color: isFav ? Colors.redAccent : Colors.blueGrey),
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                final docRef = FirebaseFirestore.instance
                                    .collection('users').doc(user!.uid)
                                    .collection('favorites').doc(chapterId);
                                if (isFav) {
                                  await docRef.delete();
                                  setState(() => _favoritedIds.remove(chapterId));
                                } else {
                                  await docRef.set({'name': chapter['name_simple'], 'id': chapter['id']});
                                  setState(() => _favoritedIds.add(chapterId));
                                }
                              },
                            ),
                            const Icon(Icons.play_circle_fill, color: Colors.blueAccent),
                          ],
                        ),
                        onTap: () => _play(chapter['id'], chapter['name_simple']),
                      );
                    },
                  ),
                ),
                
                // THE GLASSY SOUND BAR (Control Panel)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B), // Slate Blue
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  ),
                  child: Column(
                    children: [
                      Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      // THE SOUND BAR SLIDER
                      Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.white10,
                        onChanged: (v) async {
                          await _audioPlayer.seek(Duration(seconds: v.toInt()));
                        },
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(_formatDuration(_duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      IconButton(
                        iconSize: 64,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        color: Colors.white,
                        onPressed: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.resume(),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}