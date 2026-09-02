import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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

  /// Saves the processed video directly into the phone's native Gallery / Download folder.
  static Future<bool> saveVideoToGallery(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) return false;

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      if (saveDir != null) {
        final filename = p.basename(videoPath);
        final destPath = p.join(saveDir.path, filename);
        await file.copy(destPath);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
