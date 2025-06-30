import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


Future<void> sendPushToAdmins({
  required List<String> playerIds,
  required String title,
  required String content,
  Map<String, dynamic>? data,
}) async {
  const String oneSignalAppId = 'f80cbfd0-124d-4dca-bc2e-e4f021b8a872';
  const String restApiKey = 'YOUR-ONESIGNAL-REST-API-KEY'; // Keep secret

  final url = Uri.parse('https://onesignal.com/api/v1/notifications');

  final body = {
    'app_id': oneSignalAppId,
    'include_player_ids': playerIds,
    'headings': {'en': title},
    'contents': {'en': content},
    if (data != null) 'data': data,
  };

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Basic $restApiKey',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode >= 200 && response.statusCode < 300) {
    debugPrint('Notification sent successfully');
  } else {
    debugPrint('Failed to send notification: ${response.body}');
    throw Exception('OneSignal Error: ${response.body}');
  }
}
