import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'http_service.dart';
import 'storage_service.dart';

class AuthService {
  final HttpService _httpService;
  final StorageService _storageService;

  AuthService({HttpService? httpService, StorageService? storageService})
      : _httpService = httpService ?? HttpService(),
        _storageService = storageService ?? StorageService();

  Future<UserModel> register(String username, String password) async {
    final response = await _httpService.post(
      ApiConstants.register,
      body: {'username': username, 'password': password},
      requireAuth: false,
    );

    final user = UserModel.fromJson(response['user']);
    final token = response['token'];

    await _storageService.saveAuthData(
      token: token,
      userId: user.id,
      username: user.username,
    );

    return user;
  }

  Future<UserModel> login(String username, String password) async {
    final response = await _httpService.post(
      ApiConstants.login,
      body: {'username': username, 'password': password},
      requireAuth: false,
    );

    final user = UserModel.fromJson(response['user']);
    final token = response['token'];

    await _storageService.saveAuthData(
      token: token,
      userId: user.id,
      username: user.username,
    );

    return user;
  }

  Future<UserModel?> getStoredUser() async {
    final token = await _storageService.getToken();
    final userId = await _storageService.getUserId();
    final username = await _storageService.getUsername();

    if (token != null && userId != null && username != null) {
      try {
        // Silent re-authentication check with backend
        final response = await _httpService.get(
          ApiConstants.me,
          requireAuth: true,
        );
        return UserModel.fromJson(response['user']);
      } catch (e) {
        // If token invalid, return locally stored user or clear if expired
        return UserModel(id: userId, username: username);
      }
    }
    return null;
  }

  Future<void> logout() async {
    await _storageService.clearAuthData();
  }
}
