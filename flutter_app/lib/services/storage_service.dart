import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String keyToken = 'auth_jwt_token';
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'user_username';

  Future<void> saveAuthData({
    required String token,
    required String userId,
    required String username,
  }) async {
    await _storage.write(key: keyToken, value: token);
    await _storage.write(key: keyUserId, value: userId);
    await _storage.write(key: keyUsername, value: username);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: keyToken);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: keyUserId);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: keyUsername);
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: keyToken);
    await _storage.delete(key: keyUserId);
    await _storage.delete(key: keyUsername);
  }
}
