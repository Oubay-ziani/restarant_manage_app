import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ImageUploadService {
  static const String cloudName = 'oubay ziani';
  static const String uploadPreset = 'oubay123';

  static Uri get _endpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  Future<String> uploadMenuItemImage(File imageFile, {String? menuItemId}) async {
    if (cloudName == 'YOUR_CLOUD_NAME' || uploadPreset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw Exception(
        'Image upload is not configured yet. Set cloudName and uploadPreset in image_upload_service.dart.',
      );
    }

    try {
      final request = http.MultipartRequest('POST', _endpoint)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'grill_pos/menu_items'
        ..fields['public_id'] = menuItemId ?? DateTime.now().millisecondsSinceEpoch.toString()
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl == null) {
          throw Exception('Cloudinary did not return an image URL.');
        }
        return secureUrl;
      } else {
        debugPrint('Cloudinary upload failed [${response.statusCode}]: ${response.body}');
        throw Exception('Image upload failed (server error ${response.statusCode}).');
      }
    } on http.ClientException catch (e) {
      debugPrint('Cloudinary network error: $e');
      throw Exception('Image upload failed: no internet connection.');
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Cloudinary upload error: $e');
      throw Exception('Image upload failed: $e');
    }
  }

  /// Converts a local image file to a Base64 Data URL string for 100% offline storage
  Future<String> encodeImageAsBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  }
}
