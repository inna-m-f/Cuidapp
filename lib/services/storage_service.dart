import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage({
    required String folder,
    required String id,
    required Uint8List imageBytes,
  }) async {
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = _storage.ref().child('$folder/$id/$fileName');

    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }
}