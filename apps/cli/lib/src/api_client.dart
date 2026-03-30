import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl}) : _client = http.Client();

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    required String source,
    List<Map<String, dynamic>> actions = const [],
    String? callbackUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = {
      'title': title,
      'body': body,
      'source': source,
      'actions': actions,
      if (callbackUrl != null) 'callback_url': callbackUrl,
      if (metadata != null) 'metadata': metadata,
    };

    final response = await _client.post(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed (${response.statusCode}): ${response.body}');
  }

  Future<Map<String, dynamic>> listNotifications({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      if (status != null) 'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final uri = Uri.parse('$baseUrl/api/notifications')
        .replace(queryParameters: params);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed (${response.statusCode}): ${response.body}');
  }

  Future<Map<String, dynamic>> getNotification(String id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/notifications/$id'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed (${response.statusCode}): ${response.body}');
  }

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HttpException('Failed (${response.statusCode}): ${response.body}');
  }

  void dispose() => _client.close();
}
