import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static MediaType _getMediaType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'png') {
      return MediaType('image', 'png');
    } else if (ext == 'pdf') {
      return MediaType('application', 'pdf');
    } else {
      return MediaType('image', 'jpeg');
    }
  }

  // Toggle between local development and live production
  // TODO: Update productionUrl to your Render.com backend URL after deployment
  static const bool isProduction = false; // Set to true after deploying backend
  static const String productionUrl = 'https://medicine-reminder-backend.onrender.com/api';

  // Dynamic baseUrl to handle Android emulator loopback and localhost gracefully.
  static String get baseUrl {
    if (isProduction) {
      return productionUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.7:5000/api'; // PC local IP - same Wi-Fi network required
    } else {
      return 'http://127.0.0.1:5000/api';
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'bypass-tunnel-reminder': 'true',
    };
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network connection failed. $e');
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network connection failed. $e');
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network connection failed. $e');
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network connection failed. $e');
    }
  }

  // Handle prescription file upload (multipart request)
  static Future<dynamic> uploadMultipart(
    String endpoint,
    String filePath,
    Map<String, String> fields, {
    Uint8List? fileBytes,
    String? fileName,
    String method = 'POST',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      var uri = Uri.parse('$baseUrl$endpoint');
      var request = http.MultipartRequest(method, uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['bypass-tunnel-reminder'] = 'true';
      request.fields.addAll(fields);
      
      if (kIsWeb && fileBytes != null && fileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'prescription',
          fileBytes,
          filename: fileName,
          contentType: _getMediaType(fileName),
        ));
      } else if (!kIsWeb && filePath.isNotEmpty && File(filePath).existsSync()) {
        request.files.add(await http.MultipartFile.fromPath(
          'prescription',
          filePath,
          contentType: _getMediaType(filePath),
        ));
      }
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      throw Exception('Upload connection failed. $e');
    }
  }

  static dynamic _processResponse(http.Response response) {
    if (response.body.isEmpty) {
      throw Exception('Server returned an empty response. Status Code: ${response.statusCode}');
    }
    
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to parse server response. Status Code: ${response.statusCode}');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body is Map && body.containsKey('message')
          ? body['message']
          : 'Something went wrong. Status Code: ${response.statusCode}');
    }
  }
}
