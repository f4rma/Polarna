import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for uploading warehouse photos to Firebase Storage
/// and returning their download URLs.
class PhotoUploadService {
  final FirebaseStorage _storage;
  final Uuid _uuid;

  PhotoUploadService({FirebaseStorage? storage, Uuid? uuid})
      : _storage = storage ?? FirebaseStorage.instance,
        _uuid = uuid ?? const Uuid();

  /// Uploads a list of local file paths to Firebase Storage under
  /// `warehouse_photos/{warehouseId}/` and returns the download URLs.
  Future<List<String>> uploadWarehousePhotos({
    required List<String> localPaths,
    required String warehouseId,
  }) async {
    final urls = <String>[];
    for (final path in localPaths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      final ext = path.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final fileName = '${_uuid.v4()}.$ext';
      final ref = _storage.ref('warehouse_photos/$warehouseId/$fileName');

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      // Wait for upload to complete and get URL
      if (uploadTask.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    }
    return urls;
  }
}

final photoUploadServiceProvider = Provider<PhotoUploadService>((ref) {
  return PhotoUploadService();
});
