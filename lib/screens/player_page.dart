import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // REQUIRED for StreamSubscription
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
  Set<String> _favoritedIds = {}; 
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Handles for our streams (like pointers to listeners)
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadFavorites();

    // Store subscriptions so we can "free" them later
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = (state == PlayerState.playing));
    });
  }

  @override
  void dispose() {
    // Memory Management: Cancel all listeners when leaving the page
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .get();
      
      // Safety check: only update state if the user is still looking at this page
      if (!mounted) return; 
      
      setState(() {
        _favoritedIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      print("Error loading favorites: $e");
    }
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters?language=en'));
      
      if (!mounted) return; // Guard against disposed widget

      if (response.statusCode == 200) {
        setState(() {
          _tracks = json.decode(response.body)['chapters'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _play(int id, String name) async {
    if (mounted) setState(() => _currentTitle = name);
    String chapterId = id.toString().padLeft(3, '0');
    String audioUrl = "https://server8.mp3quran.net/afs/$chapterId.mp3"; 
    await _audioPlayer.play(UrlSource(audioUrl));
  }

  String _formatDuration(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0").substring(3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
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
                                if (user == null) return;

                                final docRef = FirebaseFirestore.instance
                                    .collection('users').doc(user.uid)
                                    .collection('favorites').doc(chapterId);
                                
                                if (isFav) {
                                  await docRef.delete();
                                  if (mounted) setState(() => _favoritedIds.remove(chapterId));
                                } else {
                                  await docRef.set({'name': chapter['name_simple'], 'id': chapter['id']});
                                  if (mounted) setState(() => _favoritedIds.add(chapterId));
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
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  ),
                  child: Column(
                    children: [
                      Text(_currentTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
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