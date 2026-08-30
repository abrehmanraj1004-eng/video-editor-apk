import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/video_metadata.dart';

class VideoSegment {
  final double start;
  final double end;
  final double speed;

  VideoSegment({required this.start, required this.end, required this.speed});
}

class FFmpegService {
  /// Fetches duration, resolution, fps, and audio presence for any video file on Android.
  Future<VideoMetadata> getVideoMetadata(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info == null) {
        throw Exception("Could not read video information with FFprobe");
      }

      final durationSec = double.tryParse(info.getDuration() ?? '0') ?? 0.0;
      final streams = info.getStreams();
      int width = 1920;
      int height = 1080;
      double fps = 30.0;
      bool hasAudio = false;

      for (final stream in streams) {
        if (stream.getType() == 'video') {
          width = stream.getWidth() ?? 1920;
          height = stream.getHeight() ?? 1080;
          final rFps = stream.getRealFrameRate() ?? '30/1';
          if (rFps.contains('/')) {
            final parts = rFps.split('/');
            final num = double.tryParse(parts[0]) ?? 30.0;
            final den = double.tryParse(parts[1]) ?? 1.0;
            if (den > 0) fps = num / den;
          } else {
            fps = double.tryParse(rFps) ?? 30.0;
          }
        } else if (stream.getType() == 'audio') {
          hasAudio = true;
        }
      }

      return VideoMetadata(
        title: p.basenameWithoutExtension(filePath),
        duration: durationSec,
        durationFormatted: VideoMetadata.formatSeconds(durationSec),
        localFilePath: filePath,
        width: width,
        height: height,
        fps: fps,
        hasAudio: hasAudio,
      );
    } catch (e) {
      return VideoMetadata(
        title: p.basenameWithoutExtension(filePath),
        duration: 30.0,
        durationFormatted: "00:30",
        localFilePath: filePath,
      );
    }
  }

  /// Builds a chained atempo filter because FFmpeg atempo only supports 0.5x to 2.0x in a single filter.
  String buildAtempoFilter(double speed) {
    if (speed <= 0) speed = 0.1;
    final filters = <String>[];
    var current = speed;
    while (current < 0.5) {
      filters.add("atempo=0.5");
      current /= 0.5;
    }
    while (current > 2.0) {
      filters.add("atempo=2.0");
      current /= 2.0;
    }
    filters.add("atempo=${current.toStringAsFixed(4)}");
    return filters.join(",");
  }

  /// Auto 60s Binary Search Algorithm: Slows down end of video if < 60s to make total exactly targetDuration.
  List<VideoSegment> calculateAutoTargetDurationSegments(
    double duration, {
    double targetDuration = 60.0,
    double slowdownStartPct = 0.60,
  }) {
    if (duration >= targetDuration - 0.05) {
      return [VideoSegment(start: 0.0, end: duration, speed: 1.0)];
    }

    final p1 = (slowdownStartPct - 0.15).clamp(0.0, 1.0) * duration;
    final p2 = slowdownStartPct.clamp(0.0, 0.98) * duration;

    final tNormal = p1;
    final tRamp = p2 - p1;
    final tSlow = duration - p2;

    var low = 0.01;
    var high = 0.9999;

    for (var i = 0; i < 60; i++) {
      final mid = (low + high) / 2.0;
      final rampSpeed = (1.0 + mid) / 2.0;
      final outDur = tNormal + (tRamp / rampSpeed) + (tSlow / mid);
      if (outDur > targetDuration) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final sEnd = (low + high) / 2.0;
    final rampSpd = (1.0 + sEnd) / 2.0;

    final segments = [
      VideoSegment(start: 0.0, end: p1, speed: 1.0),
      VideoSegment(start: p1, end: p2, speed: rampSpd),
      VideoSegment(start: p2, end: duration, speed: sEnd),
    ];

    return segments.where((s) => s.end > s.start + 0.01).toList();
  }

  /// Calculates curve segments for selected preset or custom speed sliders.
  List<VideoSegment> calculateCurveSegments({
    required double duration,
    required SpeedCurvePreset preset,
    double startSpeed = 1.0,
    double endSpeed = 0.22,
    double slowdownPointPct = 0.60,
    double targetSeconds = 60.0,
  }) {
    if (duration <= 0) duration = 10.0;

    List<VideoSegment> segments;

    switch (preset) {
      case SpeedCurvePreset.auto60s:
        return calculateAutoTargetDurationSegments(
          duration,
          targetDuration: targetSeconds,
          slowdownStartPct: slowdownPointPct,
        );

      case SpeedCurvePreset.endSlowdown:
        final p1 = 0.50 * duration;
        final p2 = 0.70 * duration;
        final p3 = 0.85 * duration;
        segments = [
          VideoSegment(start: 0.0, end: p1, speed: 1.0),
          VideoSegment(start: p1, end: p2, speed: (1.0 + endSpeed) * 0.65),
          VideoSegment(start: p2, end: p3, speed: endSpeed * 1.6),
          VideoSegment(start: p3, end: duration, speed: endSpeed),
        ];
        break;

      case SpeedCurvePreset.heroBullet:
        segments = [
          VideoSegment(start: 0.0, end: 0.20 * duration, speed: 1.5),
          VideoSegment(start: 0.20 * duration, end: 0.35 * duration, speed: 0.7),
          VideoSegment(start: 0.35 * duration, end: 0.65 * duration, speed: 0.25),
          VideoSegment(start: 0.65 * duration, end: 0.80 * duration, speed: 1.4),
          VideoSegment(start: 0.80 * duration, end: duration, speed: 0.35),
        ];
        break;

      case SpeedCurvePreset.flashIn:
        segments = [
          VideoSegment(start: 0.0, end: 0.25 * duration, speed: 0.25),
          VideoSegment(start: 0.25 * duration, end: 0.50 * duration, speed: 0.7),
          VideoSegment(start: 0.50 * duration, end: duration, speed: 1.5),
        ];
        break;

      case SpeedCurvePreset.montage:
        segments = [
          VideoSegment(start: 0.0, end: 0.25 * duration, speed: 1.6),
          VideoSegment(start: 0.25 * duration, end: 0.50 * duration, speed: 0.3),
          VideoSegment(start: 0.50 * duration, end: 0.75 * duration, speed: 1.6),
          VideoSegment(start: 0.75 * duration, end: duration, speed: 0.3),
        ];
        break;

      case SpeedCurvePreset.custom:
        final p1 = slowdownPointPct * 0.85 * duration;
        final p2 = slowdownPointPct * duration;
        final ramp = (startSpeed + endSpeed) / 2.0;
        segments = [
          VideoSegment(start: 0.0, end: p1, speed: startSpeed),
          VideoSegment(start: p1, end: p2, speed: ramp),
          VideoSegment(start: p2, end: duration, speed: endSpeed),
        ];
        break;
    }

    return segments.where((s) => s.end > s.start + 0.01).toList();
  }

  /// Executes on-device speed curve and motion interpolation using mobile FFmpeg.
  Future<File> processVideo({
    required String inputPath,
    required SpeedCurvePreset preset,
    bool preservePitch = true,
    bool smooth60fps = true,
    double startSpeed = 1.0,
    double endSpeed = 0.22,
    double slowdownPointPct = 0.60,
    double targetSeconds = 60.0,
    Function(ProcessingProgress)? onProgress,
  }) async {
    final meta = await getVideoMetadata(inputPath);
    final duration = meta.duration;
    final hasAudio = meta.hasAudio;

    final segments = calculateCurveSegments(
      duration: duration,
      preset: preset,
      startSpeed: startSpeed,
      endSpeed: endSpeed,
      slowdownPointPct: slowdownPointPct,
      targetSeconds: targetSeconds,
    );

    final estOutputDuration = segments.fold<double>(
      0.0,
      (sum, s) => sum + ((s.end - s.start) / s.speed),
    );

    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'edited_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final filterParts = <String>[];
    final vSegments = <String>[];
    final aSegments = <String>[];

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final vName = 'v$i';
      filterParts.add(
        '[0:v]trim=start=${seg.start.toStringAsFixed(4)}:end=${seg.end.toStringAsFixed(4)},setpts=(PTS-STARTPTS)/${seg.speed.toStringAsFixed(4)}[$vName]',
      );
      vSegments.add('[$vName]');

      if (hasAudio) {
        final aName = 'a$i';
        final atempoStr = buildAtempoFilter(seg.speed);
        filterParts.add(
          '[0:a]atrim=start=${seg.start.toStringAsFixed(4)}:end=${seg.end.toStringAsFixed(4)},asetpts=PTS-STARTPTS,$atempoStr[$aName]',
        );
        aSegments.add('[$aName]');
      }
    }

    final n = segments.length;
    final concatV = '${vSegments.join()}concat=n=$n:v=1:a=0[v_cat]';
    filterParts.add(concatV);

    String finalVLabel = '[v_cat]';

    if (smooth60fps) {
      filterParts.add('[v_cat]minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1[v_60fps]');
      finalVLabel = '[v_60fps]';
    }

    String concatA = '';
    if (hasAudio) {
      concatA = '${aSegments.join()}concat=n=$n:v=0:a=1[a_cat]';
      filterParts.add(concatA);
    }

    final filterComplex = filterParts.join(';');

    final commandArgs = <String>[
      '-y',
      '-i',
      inputPath,
      '-filter_complex',
      filterComplex,
      '-map',
      finalVLabel,
    ];

    if (hasAudio) {
      commandArgs.addAll(['-map', '[a_cat]']);
      commandArgs.addAll(['-c:a', 'aac', '-b:a', '192k']);
    }

    commandArgs.addAll([
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast', // Fast rendering on mobile CPU
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      '-movflags',
      '+faststart',
      outputPath,
    ]);

    final commandString = commandArgs.map((arg) {
      if (arg.contains(' ') || arg.contains(';') || arg.contains('=')) {
        return '"$arg"';
      }
      return arg;
    }).join(' ');

    if (onProgress != null) {
      onProgress(
        ProcessingProgress(
          percent: 5.0,
          stage: 'Initializing AI Speed Warp Engine',
          message: 'Applying speed curve to video...',
        ),
      );
    }

    final session = await FFmpegKit.executeAsync(
      commandString,
      (session) async {
        final state = await session.getState();
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          if (onProgress != null) {
            onProgress(
              ProcessingProgress(
                percent: 100.0,
                stage: 'Rendering Complete',
                message: 'Video edited successfully!',
              ),
            );
          }
        }
      },
      (log) {},
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && estOutputDuration > 0) {
          final currentSec = timeMs / 1000.0;
          final pct = (currentSec / estOutputDuration * 100.0).clamp(5.0, 99.0);
          if (onProgress != null) {
            onProgress(
              ProcessingProgress(
                percent: pct,
                stage: 'Rendering Video (${pct.toStringAsFixed(0)}%)',
                message: 'Processing frame at ${statistics.getVideoFps().toStringAsFixed(1)} FPS...',
              ),
            );
          }
        }
      },
    );

    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception("FFmpeg processing failed: $logs");
    }

    final outFile = File(outputPath);
    if (!await outFile.exists()) {
      throw Exception("Output file was not created.");
    }

    return outFile;
  }

  void cancel() {
    FFmpegKit.cancel();
  }
}
