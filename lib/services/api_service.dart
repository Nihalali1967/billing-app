import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static String? _token;
  static bool _enableLogging = true;

  static void setLogging(bool enable) => _enableLogging = enable;

  static void _log(String method, String url,
      {Map<String, dynamic>? body,
      Map<String, String>? queryParams,
      int? statusCode,
      String? error}) {
    if (!_enableLogging) return;
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────');
    buffer.writeln('│ API [$method] $url');
    if (queryParams != null && queryParams.isNotEmpty) {
      buffer.writeln('│ Query: $queryParams');
    }
    if (body != null && body.isNotEmpty) {
      buffer.writeln('│ Body: ${jsonEncode(body)}');
    }
    if (statusCode != null) {
      final statusEmoji = statusCode >= 200 && statusCode < 300
          ? '✅'
          : statusCode >= 400
              ? '❌'
              : '⚠️';
      buffer.writeln('│ Status: $statusEmoji $statusCode');
    }
    if (error != null) {
      buffer.writeln('│ Error: $error');
    }
    buffer.write('└─────────────────────────────────────────');
    // ignore: avoid_print
    print(buffer.toString());
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static String? get token => _token;
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    _log('GET', uri.toString(), queryParams: queryParams);
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(ApiConfig.timeout);
      _log('GET', uri.toString(),
          queryParams: queryParams,
          statusCode: response.statusCode);
      return _handleResponse(response, method: 'GET', url: uri.toString());
    } catch (e) {
      _log('GET', uri.toString(),
          queryParams: queryParams, error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _log('POST', uri.toString(), body: body);
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(ApiConfig.timeout);
      _log('POST', uri.toString(),
          body: body, statusCode: response.statusCode);
      return _handleResponse(response, method: 'POST', url: uri.toString(), body: body);
    } catch (e) {
      _log('POST', uri.toString(), body: body, error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _log('PUT', uri.toString(), body: body);
    try {
      final response = await http
          .put(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(ApiConfig.timeout);
      _log('PUT', uri.toString(),
          body: body, statusCode: response.statusCode);
      return _handleResponse(response, method: 'PUT', url: uri.toString(), body: body);
    } catch (e) {
      _log('PUT', uri.toString(), body: body, error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _log('DELETE', uri.toString());
    try {
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(ApiConfig.timeout);
      _log('DELETE', uri.toString(), statusCode: response.statusCode);
      return _handleResponse(response, method: 'DELETE', url: uri.toString());
    } catch (e) {
      _log('DELETE', uri.toString(), error: e.toString());
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    File? file,
    String fileField = 'image',
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    _log('POST-MULTIPART', uri.toString(),
        body: fields?.map((k, v) => MapEntry(k, v as dynamic)));
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      });
      if (fields != null) request.fields.addAll(fields);
      if (file != null) {
        request.files
            .add(await http.MultipartFile.fromPath(fileField, file.path));
      }
      final streamedResponse =
          await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      _log('POST-MULTIPART', uri.toString(),
          body: fields?.map((k, v) => MapEntry(k, v as dynamic)),
          statusCode: response.statusCode);
      return _handleResponse(response, method: 'POST-MULTIPART', url: uri.toString());
    } catch (e) {
      _log('POST-MULTIPART', uri.toString(),
          body: fields?.map((k, v) => MapEntry(k, v as dynamic)),
          error: e.toString());
      rethrow;
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response,
      {String? method, String? url, Map<String, dynamic>? body}) {
    final decodedBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    } else if (response.statusCode == 401) {
      _log(method ?? 'RESPONSE', url ?? '',
          body: body, statusCode: 401, error: 'Unauthenticated');
      throw ApiException('Unauthenticated', 401);
    } else if (response.statusCode == 403) {
      _log(method ?? 'RESPONSE', url ?? '',
          body: body, statusCode: 403, error: 'Forbidden');
      throw ApiException('Forbidden', 403);
    } else if (response.statusCode == 422) {
      final errors = decodedBody['errors'] as Map<String, dynamic>?;
      final message = decodedBody['message'] ?? 'Validation error';
      _log(method ?? 'RESPONSE', url ?? '',
          body: body,
          statusCode: 422,
          error: '$message | errors: $errors');
      throw ValidationException(message, errors);
    } else if (response.statusCode == 404) {
      _log(method ?? 'RESPONSE', url ?? '',
          body: body, statusCode: 404, error: 'Not found');
      throw ApiException('Not found', 404);
    } else {
      _log(method ?? 'RESPONSE', url ?? '',
          body: body,
          statusCode: response.statusCode,
          error: decodedBody['message'] ?? 'Server error');
      throw ApiException(
          decodedBody['message'] ?? 'Server error', response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(String message, this.errors) : super(message, 422);

  String get firstError {
    if (errors != null && errors!.isNotEmpty) {
      final firstField = errors!.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first.toString();
      }
    }
    return message;
  }
}
