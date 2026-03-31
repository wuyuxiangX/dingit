import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };

  Future<void> patchNotificationStatus(String id, String status) async {
    final url = Uri.parse('$baseUrl/api/notifications/$id');
    try {
      final response = await _client.patch(
        url,
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode != 200) {
        debugPrint(
          '[ApiClient] PATCH $url failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[ApiClient] PATCH $url error: $e');
    }
  }
}
