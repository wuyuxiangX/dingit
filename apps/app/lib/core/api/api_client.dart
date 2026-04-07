import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dingit_shared/dingit_shared.dart';

class PaginatedNotifications {
  final List<NotificationModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedNotifications({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

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

  Future<PaginatedNotifications> getNotifications({
    String? status,
    String? priority,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (status case final s?) 'status': s,
      if (priority case final p?) 'priority': p,
    };
    final url = Uri.parse('$baseUrl/api/notifications').replace(queryParameters: params);

    final response = await _client.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }

    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>;
    final itemsList = (data['items'] as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedNotifications(
      items: itemsList,
      total: data['total'] as int,
      page: data['page'] as int,
      pageSize: data['page_size'] as int,
      totalPages: data['total_pages'] as int,
    );
  }

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

  Future<void> registerDevice({required String token, required String platform}) async {
    final url = Uri.parse('$baseUrl/api/devices');
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to register device: ${response.statusCode}');
    }
  }
}
