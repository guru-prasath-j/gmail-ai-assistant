import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String _baseUrl = 'http://localhost:8000';
  static final _storage = FlutterSecureStorage();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120), // LLM can be slow
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(LogInterceptor(responseBody: false));

  static Future<bool> checkHealth() async {
    try { final r = await _dio.get('/health'); return r.statusCode == 200; } catch (_) { return false; }
  }
  static Future<String> getLoginUrl() async {
    final r = await _dio.get('/auth/login'); return r.data['auth_url'];
  }
  static Future<Map<String, dynamic>> getAuthStatus() async {
    final r = await _dio.get('/auth/status'); return Map<String, dynamic>.from(r.data);
  }
  static Future<List<Map<String, dynamic>>> getInbox({int maxResults = 20, bool unreadOnly = true}) async {
    final r = await _dio.get('/emails/inbox', queryParameters: { 'max_results': maxResults, 'unread_only': unreadOnly });
    return List<Map<String, dynamic>>.from(r.data['emails']);
  }
  static Future<String> generateReply({required String gmailMessageId, required String threadId, required String subject, required String sender, required String body, bool save = true}) async {
    final r = await _dio.post('/llm/generate-reply', data: {'gmail_message_id': gmailMessageId, 'thread_id': threadId, 'subject': subject, 'sender': sender, 'body': body, 'save': save});
    return r.data['reply'] as String;
  }
  static Future<void> sendReply({required String gmailMessageId, required String threadId, required String to, required String subject, required String replyBody}) async {
    await _dio.post('/emails/send-reply', data: {'gmail_message_id': gmailMessageId, 'thread_id': threadId, 'to': to, 'subject': subject, 'reply_body': replyBody});
  }
}
