import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  /// Uploads [image] to Firebase Storage under [folder].
  /// Falls back to Base64 data URI if Storage upload fails.
  static Future<String?> upload(XFile image, {String folder = 'evidence'}) async {
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child('$folder/$filename');
      final metadata = SettableMetadata(contentType: image.mimeType ?? 'image/jpeg');
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload failed ($e) — using Base64 fallback');
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      return 'data:${image.mimeType ?? "image/jpeg"};base64,$b64';
    }
  }
}
