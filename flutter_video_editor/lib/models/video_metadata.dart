class VideoMetadata {
  final String title;
  final double duration; // in seconds
  final String durationFormatted;
  final String? thumbnailUrl;
  final String? author;
  final int? viewCount;
  final String? localFilePath;
  final int width;
  final int height;
  final double fps;
  final bool hasAudio;

  VideoMetadata({
    required this.title,
    required this.duration,
    required this.durationFormatted,
    this.thumbnailUrl,
    this.author,
    this.viewCount,
    this.localFilePath,
    this.width = 1920,
    this.height = 1080,
    this.fps = 30.0,
    this.hasAudio = true,
  });

  static String formatSeconds(double seconds) {
    final int totalSec = seconds.toInt();
    final int m = (totalSec % 3600) ~/ 60;
    final int s = totalSec % 60;
    final int h = totalSec ~/ 3600;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

enum SpeedCurvePreset {
  auto60s,
  endSlowdown,
  heroBullet,
  flashIn,
  montage,
  custom,
}

extension SpeedCurvePresetExtension on SpeedCurvePreset {
  String get title {
    switch (this) {
      case SpeedCurvePreset.auto60s:
        return '🎯 Auto 60s (Slowdown End if <60s, Keep if >=60s)';
      case SpeedCurvePreset.endSlowdown:
        return '⚡ CapCut Flash-Out (Smooth Slow-mo End)';
      case SpeedCurvePreset.heroBullet:
        return '🦸 Hero / Bullet (Fast -> Climax Slow -> Fast)';
      case SpeedCurvePreset.flashIn:
        return '💥 Flash In (Super Slow Start -> Fast End)';
      case SpeedCurvePreset.montage:
        return '🎵 Montage Rhythm (Fast -> Slow -> Fast -> Slow)';
      case SpeedCurvePreset.custom:
        return '⚙️ Custom Speed Warp & Sliders';
    }
  }

  String get shortName {
    switch (this) {
      case SpeedCurvePreset.auto60s:
        return 'Auto 60s';
      case SpeedCurvePreset.endSlowdown:
        return 'Slow-mo End';
      case SpeedCurvePreset.heroBullet:
        return 'Hero Bullet';
      case SpeedCurvePreset.flashIn:
        return 'Flash In';
      case SpeedCurvePreset.montage:
        return 'Montage';
      case SpeedCurvePreset.custom:
        return 'Custom';
    }
  }

  String get icon {
    switch (this) {
      case SpeedCurvePreset.auto60s:
        return '🎯';
      case SpeedCurvePreset.endSlowdown:
        return '⚡';
      case SpeedCurvePreset.heroBullet:
        return '🦸';
      case SpeedCurvePreset.flashIn:
        return '💥';
      case SpeedCurvePreset.montage:
        return '🎵';
      case SpeedCurvePreset.custom:
        return '⚙️';
    }
  }
}

class ProcessingProgress {
  final double percent; // 0 to 100
  final String stage;
  final String message;
  final double? speedMb;
  final int? etaSeconds;

  ProcessingProgress({
    required this.percent,
    required this.stage,
    required this.message,
    this.speedMb,
    this.etaSeconds,
  });
}
