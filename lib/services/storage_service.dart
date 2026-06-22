import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage({
    required String folder,
    required String id,
    required Uint8List imageBytes,
  }) async {
    final String fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final String path = '$folder/$id/$fileName';

    debugPrint('=== FIREBASE STORAGE ===');
    debugPrint('Ruta destino: $path');
    debugPrint('Tamaño imagen: ${imageBytes.length} bytes');
    debugPrint('Bucket: ${_storage.bucket}');

    final Reference ref = _storage.ref().child(path);

    final UploadTask uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'folder': folder,
          'id': id,
        },
      ),
    );

    final TaskSnapshot snapshot = await uploadTask;

    debugPrint('Estado subida: ${snapshot.state}');
    debugPrint('Bytes transferidos: ${snapshot.bytesTransferred}');
    debugPrint('Total bytes: ${snapshot.totalBytes}');
    debugPrint('Full path: ${snapshot.ref.fullPath}');

    final String downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('Download URL: $downloadUrl');
    debugPrint('=== FIN FIREBASE STORAGE ===');

    return downloadUrl;
  }
}