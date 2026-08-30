import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/video_metadata.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Fetches video details from a YouTube URL without downloading the file.
  Future<VideoMetadata> fetchVideoInfo(String url) async {
    try {
      final videoId = VideoId(url.trim());
      final video = await _yt.videos.get(videoId);

      final double durationSec = (video.duration?.inSeconds ?? 0).toDouble();

      return VideoMetadata(
        title: video.title,
        duration: durationSec,
        durationFormatted: VideoMetadata.formatSeconds(durationSec),
        thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.mediumResUrl,
        author: video.author,
        viewCount: video.engagement.viewCount,
      );
    } catch (e) {
      throw Exception("Failed to load YouTube video info: ${e.toString()}");
    }
  }

  /// Downloads the YouTube video stream to the device's temporary directory.
  Future<File> downloadVideo(
    String url, {
    String resolution = 'best',
    Function(ProcessingProgress)? onProgress,
    bool Function()? cancelCheck,
  }) async {
    try {
      final videoId = VideoId(url.trim());
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Select muxed (video + audio) or best video stream
      StreamInfo streamInfo;
      if (resolution == '720' && manifest.muxed.isNotEmpty) {
        streamInfo = manifest.muxed.firstWhere(
          (s) => s.videoQualityLabel.contains('720'),
          orElse: () => manifest.muxed.withHighestBitrate(),
        );
      } else if (resolution == '480' && manifest.muxed.isNotEmpty) {
        streamInfo = manifest.muxed.firstWhere(
          (s) => s.videoQualityLabel.contains('480'),
          orElse: () => manifest.muxed.withHighestBitrate(),
        );
      } else {
        streamInfo = manifest.muxed.isNotEmpty
            ? manifest.muxed.withHighestBitrate()
            : manifest.videoOnly.withHighestBitrate();
      }

      final tempDir = await getTemporaryDirectory();
      // Sanitize filename
      final safeTitle = video.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final targetPath = p.join(
        tempDir.path,
        '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.${streamInfo.container.name}',
      );
      final file = File(targetPath);
      final output = file.openWrite();

      final stream = _yt.videos.streamsClient.get(streamInfo);
      final totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;
      final startTime = DateTime.now();

      await for (final data in stream) {
        if (cancelCheck != null && cancelCheck()) {
          await output.flush();
          await output.close();
          if (await file.exists()) await file.delete();
          throw Exception("Download cancelled by user.");
        }

        output.add(data);
        downloadedBytes += data.length;

        final elapsedSec = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        final speedMb = elapsedSec > 0 ? (downloadedBytes / (1024 * 1024)) / elapsedSec : 0.0;
        final percent = totalBytes > 0 ? (downloadedBytes / totalBytes) * 100.0 : 0.0;
        final remainingBytes = totalBytes - downloadedBytes;
        final eta = (speedMb > 0 && remainingBytes > 0)
            ? (remainingBytes / (1024 * 1024) / speedMb).round()
            : 0;

        if (onProgress != null) {
          onProgress(
            ProcessingProgress(
              percent: percent.clamp(0.0, 100.0),
              stage: 'Downloading YouTube Video',
              message:
                  'Downloaded: ${percent.toStringAsFixed(1)}% (${speedMb.toStringAsFixed(2)} MB/s, ETA: ${eta}s)',
              speedMb: speedMb,
              etaSeconds: eta,
            ),
          );
        }
      }

      await output.flush();
      await output.close();

      return file;
    } catch (e) {
      throw Exception("YouTube Download error: ${e.toString()}");
    }
  }

  void dispose() {
    _yt.close();
  }
}
