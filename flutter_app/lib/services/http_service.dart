import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'storage_service.dart';

class HttpService {
  final StorageService _storageService;

  HttpService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  String get _baseUrl {
    try {
      if (Platform.isAndroid) {
        return ApiConstants.baseUrl;
      }
    } catch (e) {
      // Desktop or Web
    }
    return ApiConstants.baseUrlLocal;
  }

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (requireAuth) {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParameters, bool requireAuth = false}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParameters);
      final headers = await _getHeaders(requireAuth: requireAuth);

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Failed to connect to backend server at $_baseUrl.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please ensure backend server is running on port 5000.');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, bool requireAuth = true}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(requireAuth: requireAuth);

      final response = await http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Failed to connect to backend server at $_baseUrl.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please ensure backend server is running on port 5000.');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, {dynamic body, bool requireAuth = true}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(requireAuth: requireAuth);

      final response = await http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Failed to connect to backend server at $_baseUrl.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please ensure backend server is running on port 5000.');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> delete(String endpoint, {bool requireAuth = true}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(requireAuth: requireAuth);

      final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Failed to connect to backend server at $_baseUrl.');
    } on TimeoutException {
      throw Exception('Server connection timed out. Please ensure backend server is running on port 5000.');
    } catch (e) {
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      throw Exception(body is Map && body.containsKey('error') ? body['error'] : 'Unauthorized session.');
    } else if (response.statusCode == 429) {
      throw Exception(body is Map && body.containsKey('error') ? body['error'] : 'Rate limit exceeded.');
    } else {
      final errorMsg = (body is Map && body.containsKey('error')) ? body['error'] : 'Server error (${response.statusCode})';
      throw Exception(errorMsg);
    }
  }
}
