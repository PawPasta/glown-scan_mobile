import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.dateOfBirth,
    required this.gender,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? dateOfBirth;
  final String? gender;

  factory UserProfile.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The profile response is invalid.');
    }

    final id = value['id'];
    final fullName = value['fullName'];
    final avatarUrl = value['avatarUrl'];
    final dateOfBirth = value['dateOfBirth'];
    final gender = value['gender'];
    if (id is! String || fullName != null && fullName is! String) {
      throw const ApiException(
        'The profile response is missing required profile details.',
      );
    }
    if (avatarUrl != null && avatarUrl is! String ||
        dateOfBirth != null && dateOfBirth is! String ||
        gender != null && gender is! String) {
      throw const ApiException('The profile response contains invalid fields.');
    }

    return UserProfile(
      id: id,
      fullName: fullName as String?,
      avatarUrl: avatarUrl as String?,
      dateOfBirth: dateOfBirth as String?,
      gender: gender as String?,
    );
  }
}

class CloudinaryUploadIntent {
  const CloudinaryUploadIntent({
    required this.publicId,
    required this.timestamp,
    required this.signature,
    required this.apiKey,
    required this.cloudName,
  });

  final String publicId;
  final int timestamp;
  final String signature;
  final String apiKey;
  final String cloudName;

  factory CloudinaryUploadIntent.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The avatar upload intent is invalid.');
    }

    final publicId = value['publicId'];
    final timestamp = value['timestamp'];
    final signature = value['signature'];
    final apiKey = value['apiKey'];
    final cloudName = value['cloudName'];
    if (publicId is! String ||
        timestamp is! int ||
        signature is! String ||
        apiKey is! String ||
        cloudName is! String) {
      throw const ApiException(
        'The avatar upload intent is missing required Cloudinary details.',
      );
    }

    return CloudinaryUploadIntent(
      publicId: publicId,
      timestamp: timestamp,
      signature: signature,
      apiKey: apiKey,
      cloudName: cloudName,
    );
  }
}

abstract interface class AccountApiContract {
  Future<UserProfile> getProfile();

  Future<UserProfile> updateProfile({
    required String? fullName,
    required String? dateOfBirth,
    required String? gender,
  });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<UserProfile> uploadAvatar(XFile image);
}

class AccountApi implements AccountApiContract {
  AccountApi({ApiClient? apiClient, http.Client? cloudinaryClient})
    : _apiClient = apiClient ?? ApiClient(),
      _cloudinaryClient = cloudinaryClient ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _cloudinaryClient;

  @override
  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get(
      ApiEndpoints.profile,
      requiresAuth: true,
    );
    return _parseProfileResponse(response.data);
  }

  @override
  Future<UserProfile> updateProfile({
    required String? fullName,
    required String? dateOfBirth,
    required String? gender,
  }) async {
    final response = await _apiClient.request(
      ApiMethod.patch,
      ApiEndpoints.profile,
      json: {
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
      },
      requiresAuth: true,
    );
    return _parseProfileResponse(response.data);
  }

  UserProfile _parseProfileResponse(Object? value) {
    final data = value;
    if (data is! Map<String, dynamic>) {
      throw const ApiException('The profile response is invalid.');
    }
    return UserProfile.fromJson(data['profile']);
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      ApiEndpoints.changePassword,
      json: {'oldPassword': oldPassword, 'newPassword': newPassword},
      requiresAuth: true,
    );
  }

  @override
  Future<UserProfile> uploadAvatar(XFile image) async {
    final intentResponse = await _apiClient.post(
      ApiEndpoints.avatarUploadIntent,
      requiresAuth: true,
    );
    final intent = CloudinaryUploadIntent.fromJson(intentResponse.data);
    final cloudinaryRequest =
        http.MultipartRequest(
            'POST',
            Uri.https(
              'api.cloudinary.com',
              '/v1_1/${Uri.encodeComponent(intent.cloudName)}/image/upload',
            ),
          )
          ..fields['public_id'] = intent.publicId
          ..fields['timestamp'] = '${intent.timestamp}'
          ..fields['signature'] = intent.signature
          ..fields['api_key'] = intent.apiKey
          ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final streamedResponse = await _cloudinaryClient.send(cloudinaryRequest);
    final cloudinaryResponse = await http.Response.fromStream(streamedResponse);
    final Map<String, dynamic> uploaded;
    try {
      final decoded = jsonDecode(utf8.decode(cloudinaryResponse.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      uploaded = decoded;
    } on FormatException catch (error) {
      throw ApiException(
        'Cloudinary returned an invalid response: ${error.message}',
        statusCode: cloudinaryResponse.statusCode,
      );
    }

    if (cloudinaryResponse.statusCode < 200 ||
        cloudinaryResponse.statusCode >= 300) {
      final error = uploaded['error'];
      final message =
          error is Map<String, dynamic> && error['message'] is String
          ? error['message'] as String
          : 'Cloudinary could not upload this image.';
      throw ApiException(message, statusCode: cloudinaryResponse.statusCode);
    }

    final publicId = uploaded['public_id'];
    final version = uploaded['version'];
    final signature = uploaded['signature'];
    final secureUrl = uploaded['secure_url'];
    if (publicId is! String ||
        version is! int ||
        signature is! String ||
        secureUrl is! String) {
      throw const ApiException(
        'Cloudinary did not return all required upload confirmation details.',
      );
    }

    await _apiClient.post(
      ApiEndpoints.avatarConfirm,
      json: {
        'publicId': publicId,
        'version': version,
        'signature': signature,
        'secureUrl': secureUrl,
      },
      requiresAuth: true,
    );
    return getProfile();
  }

  void close() {
    _apiClient.close();
    _cloudinaryClient.close();
  }
}
