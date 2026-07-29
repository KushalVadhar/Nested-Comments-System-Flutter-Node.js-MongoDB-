class ApiConstants {
  // Base URLs - Adjust according to platform (10.0.2.2 for Android Emulator, localhost for iOS/Desktop)
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String wsUrl = 'ws://10.0.2.2:5000';

  // Fallback / Desktop / iOS URL:
  static const String baseUrlLocal = 'http://localhost:5000/api';
  static const String wsUrlLocal = 'ws://localhost:5000';

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
