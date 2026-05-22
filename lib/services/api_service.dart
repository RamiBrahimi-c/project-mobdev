import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<dynamic>> fetchPlaylist() async {
    final response = await http.get(Uri.parse('https://quran.yousefheiba.com/api/surahs')); 
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load playlist');
    }
  }
}