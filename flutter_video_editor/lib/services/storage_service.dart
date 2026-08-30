import 'dart:io';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  /// Requests necessary storage / video permissions on Android.
  static Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      final videoStatus = await Permission.videos.request();
      final photosStatus = await Permission.photos.request();
      final storageStatus = await Permission.storage.request();

      return videoStatus.isGranted || photosStatus.isGranted || storageStatus.isGranted;
    }
    return true;
  }

  /// Saves the processed video directly into the phone's native Gallery / Camera Roll.
  static Future<bool> saveVideoToGallery(String videoPath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putVideo(videoPath, album: 'AbdulRehman Editor');
      return true;
    } catch (e) {
      return false;
    }
  }
}
