import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: null,
    receiveTimeout: const Duration(seconds: 180),
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(LogInterceptor(responseBody: false));

  static Future<bool> checkHealth() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getLoginUrl() async {
    final r = await _dio.get('/auth/login');
    return r.data['auth_url'] as String;
  }

  static Future<Map<String, dynamic>> getAuthStatus() async {
    final r = await _dio.get('/auth/status');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> logout() async {
    await _dio.delete('/auth/logout');
  }

  static Future<Map<String, dynamic>> getOllamaStatus() async {
    final r = await _dio.get('/llm/status');
    return {'available': r.data['running'] == true, ...Map<String, dynamic>.from(r.data)};
  }

  static Future<Map<String, dynamic>?> getStyleProfile() async {
    final r = await _dio.get('/profile/');
    if (r.data['exists'] == true) return Map<String, dynamic>.from(r.data);
    return null;
  }

  static Future<void> deleteProfile() async {
    await _dio.delete('/profile/');
  }

  static Future<Map<String, dynamic>> analyzeTone(List<Map<String, String>> samples) async {
    final r = await _dio.post('/llm/analyze-tone', data: {'samples': samples});
    return Map<String, dynamic>.from(r.data);
  }

  static Future<List<Map<String, dynamic>>> getInbox({int maxResults = 20, bool unreadOnly = false}) async {
    final r = await _dio.get('/emails/inbox', queryParameters: {'max_results': maxResults, 'unread_only': unreadOnly});
    return List<Map<String, dynamic>>.from(r.data['emails']);
  }

  static Future<List<Map<String, dynamic>>> getReplies() async {
    final r = await _dio.get('/emails/replies');
    return List<Map<String, dynamic>>.from(r.data['replies']);
  }

  static Future<String> generateReply({
    required String gmailMessageId,
    required String threadId,
    required String subject,
    required String sender,
    required String body,
    bool save = true,
  }) async {
    final r = await _dio.post('/llm/generate-reply', data: {
      'gmail_message_id': gmailMessageId,
      'thread_id': threadId,
      'subject': subject,
      'sender': sender,
      'body': body,
      'save': save,
    });
    return r.data['reply'] as String;
  }

  static Future<String> regenerateReply({
    required String gmailMessageId,
    required String subject,
    required String sender,
    required String body,
    String? instruction,
  }) async {
    final r = await _dio.post('/llm/regenerate-reply', data: {
      'gmail_message_id': gmailMessageId,
      'subject': subject,
      'sender': sender,
      'body': body,
      if (instruction != null) 'instruction': instruction,
    });
    return r.data['reply'] as String;
  }

  static Future<void> sendReply({
    required String gmailMessageId,
    required String threadId,
    required String to,
    required String subject,
    required String replyBody,
  }) async {
    await _dio.post('/emails/send-reply', data: {
      'gmail_message_id': gmailMessageId,
      'thread_id': threadId,
      'to': to,
      'subject': subject,
      'reply_body': replyBody,
    });
  }

  static Future<void> updateStatus(String gmailMessageId, String status, {String? editedReply}) async {
    await _dio.post('/emails/update-status', data: {
      'gmail_message_id': gmailMessageId,
      'status': status,
      if (editedReply != null) 'edited_reply': editedReply,
    });
  }

  static Future<void> markRead(String messageId) async {
    await _dio.post('/emails/mark-read/$messageId');
  }
}
