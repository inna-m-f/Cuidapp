import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../core/theme.dart';

class ImageHelper {
  static Future<String?> cropImage({
    required String sourcePath,
    required bool isSquare,
  }) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar Foto',
          toolbarColor: AppTheme.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: isSquare ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
          lockAspectRatio: isSquare,
          aspectRatioPresets: isSquare
              ? [CropAspectRatioPreset.square]
              : [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
        ),
        IOSUiSettings(
          title: 'Recortar Foto',
          aspectRatioLockEnabled: isSquare,
          aspectRatioPresets: isSquare
              ? [CropAspectRatioPreset.square]
              : [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.square,
                  CropAspectRatioPreset.ratio3x2,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio16x9,
                ],
        ),
      ],
    );
    return croppedFile?.path;
  }
}
