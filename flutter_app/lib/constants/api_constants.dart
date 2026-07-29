class ApiConstants {
  // Live Render Production Cloud URLs (Works 24/7 for anyone, anywhere):
  static const String baseUrl = 'https://nested-comments-system-flutter-node-js.onrender.com/api';
  static const String wsUrl = 'wss://nested-comments-system-flutter-node-js.onrender.com';

  // Local Emulator / Desktop testing fallback:
  static const String baseUrlLocal = 'http://10.0.2.2:5000/api';
  static const String wsUrlLocal = 'ws://10.0.2.2:5000';

  // Auth Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Comment Endpoints
  static const String comments = '/comments';
  static const String allComments = '/comments/all';
  static const String searchComments = '/comments/search';
  static const String missedEvents = '/comments/events';
  
  static String likeComment(String id) => '/comments/$id/like';
  static String editComment(String id) => '/comments/$id';
  static String deleteComment(String id) => '/comments/$id';
}
