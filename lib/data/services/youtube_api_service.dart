import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model for a track returned from the API
class ApiTrack {
  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final String streamUrl;
  final int durationMs;
  final String source; // 'youtube' or 'jiosaavn'

  const ApiTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.streamUrl,
    required this.durationMs,
    required this.source,
  });

  factory ApiTrack.fromYouTube(Map<String, dynamic> json, String streamUrl) {
    return ApiTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['uploader'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      streamUrl: streamUrl,
      durationMs: ((json['duration'] as num?)?.toInt() ?? 0) * 1000,
      source: 'youtube',
    );
  }

  factory ApiTrack.fromJioSaavn(Map<String, dynamic> json) {
    return ApiTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      streamUrl: json['stream_url'] as String? ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      source: 'jiosaavn',
    );
  }
}

class MusicApiService {
  static const String baseUrl = 'https://music-api-tq5i.onrender.com';

  // ─── Get a direct streamable audio URL from a YouTube video URL ─────────────
  // Uses yt-dlp's extract_info (NO download). Returns a direct CDN link that
  // just_audio can stream instantly.
  static Future<Map<String, dynamic>?> getYouTubeStreamUrl(String youtubeUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/stream').replace(queryParameters: {
        'url': youtubeUrl,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(response.body);
      debugPrint('[MusicApiService] /stream error: ${err['error']}');
      return null;
    } catch (e) {
      debugPrint('[MusicApiService] Network error: $e');
      return null;
    }
  }

  // ─── Search YouTube for tracks ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchYouTube(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['tracks'] as List);
      }
    } catch (e) {
      debugPrint('[MusicApiService] YouTube search error: $e');
    }
    return [];
  }

  // ─── Search JioSaavn — returns tracks WITH direct stream URLs ───────────────
  // JioSaavn has millions of Bollywood, Hindi, Tamil, English songs — free!
  static Future<List<ApiTrack>> searchJioSaavn(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/jiosaavn/search').replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = List<Map<String, dynamic>>.from(data['tracks'] as List);
        return list
            .where((t) => (t['stream_url'] as String?)?.isNotEmpty == true)
            .map((t) => ApiTrack.fromJioSaavn(t))
            .toList();
      }
    } catch (e) {
      debugPrint('[MusicApiService] JioSaavn search error: $e');
    }
    return [];
  }

  // ─── Get JioSaavn stream URL by song ID ─────────────────────────────────────
  static Future<String?> getJioSaavnStream(String songId) async {
    try {
      final uri = Uri.parse('$baseUrl/jiosaavn/stream').replace(queryParameters: {
        'id': songId,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['stream_url'] as String?;
      }
    } catch (e) {
      debugPrint('[MusicApiService] JioSaavn stream error: $e');
    }
    return null;
  }
}
