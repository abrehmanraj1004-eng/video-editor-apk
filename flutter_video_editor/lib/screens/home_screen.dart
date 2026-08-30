import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/video_metadata.dart';
import '../services/youtube_service.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/video_info_card.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YouTubeService _ytService = YouTubeService();
  final FFmpegService _ffmpegService = FFmpegService();
  final TextEditingController _urlController = TextEditingController();

  // Mode: 0 for YouTube, 1 for Local Video
  int _selectedMode = 0;

  VideoMetadata? _loadedVideo;
  String? _localVideoPath;
  bool _isLoadingInfo = false;

  // Settings & Presets
  SpeedCurvePreset _selectedPreset = SpeedCurvePreset.auto60s;
  bool _smooth60Fps = true;
  bool _preservePitch = true;
  String _selectedResolution = 'best';

  // Custom Speed Sliders
  double _startSpeed = 1.0;
  double _endSpeed = 0.22;
  double _slowdownPoint = 60.0;
  double _targetSeconds = 60.0;

  // Processing State
  bool _isProcessing = false;
  bool _cancelRequested = false;
  ProcessingProgress? _currentProgress;

  @override
  void dispose() {
    _urlController.dispose();
    _ytService.dispose();
    super.dispose();
  }

  Future<void> _fetchYouTubeInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showToast('Please enter a YouTube video URL');
      return;
    }

    setState(() {
      _isLoadingInfo = true;
      _loadedVideo = null;
    });

    try {
      final info = await _ytService.fetchVideoInfo(url);
      setState(() {
        _loadedVideo = info;
        _isLoadingInfo = false;
      });
    } catch (e) {
      setState(() => _isLoadingInfo = false);
      _showToast('Error: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  Future<void> _pickLocalVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() => _isLoadingInfo = true);
        
        final info = await _ffmpegService.getVideoMetadata(path);
        setState(() {
          _localVideoPath = path;
          _loadedVideo = info;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingInfo = false);
      _showToast('Failed to pick video: $e');
    }
  }

  Future<void> _startProcessing() async {
    if (_selectedMode == 0 && (_urlController.text.trim().isEmpty || _loadedVideo == null)) {
      _showToast('Please fetch a YouTube video first');
      return;
    }
    if (_selectedMode == 1 && (_localVideoPath == null || _loadedVideo == null)) {
      _showToast('Please select a local video first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _cancelRequested = false;
      _currentProgress = ProcessingProgress(
        percent: 0.0,
        stage: 'Starting Editor',
        message: 'Preparing video processing pipeline...',
      );
    });

    File? downloadedFile;
    try {
      String videoToProcessPath;

      // 1. Download YouTube video if in YouTube Mode
      if (_selectedMode == 0) {
        downloadedFile = await _ytService.downloadVideo(
          _urlController.text.trim(),
          resolution: _selectedResolution,
          cancelCheck: () => _cancelRequested,
          onProgress: (p) => setState(() => _currentProgress = p),
        );
        videoToProcessPath = downloadedFile.path;
      } else {
        videoToProcessPath = _localVideoPath!;
      }

      if (_cancelRequested) throw Exception("Process cancelled by user.");

      // 2. Apply Speed Curve & 60 FPS using Mobile FFmpeg
      final processedFile = await _ffmpegService.processVideo(
        inputPath: videoToProcessPath,
        preset: _selectedPreset,
        preservePitch: _preservePitch,
        smooth60fps: _smooth60Fps,
        startSpeed: _startSpeed,
        endSpeed: _endSpeed,
        slowdownPointPct: _slowdownPoint / 100.0,
        targetSeconds: _targetSeconds,
        onProgress: (p) => setState(() => _currentProgress = p),
      );

      setState(() => _isProcessing = false);

      // Open Preview Player Screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              videoFile: processedFile,
              title: _loadedVideo?.title ?? 'Edited Video',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showToast('Processing Error: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  void _cancelProcess() {
    _cancelRequested = true;
    _ffmpegService.cancel();
    setState(() => _isProcessing = false);
    _showToast('Processing cancelled');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F2937),
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Top App Bar Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                            ),
                            child: const Text('🎬', style: TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'AbdulRehman Editor',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF38BDF8),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'PRO AI',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0B0F19),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'AI Speed Curve • Auto 60s • 60 FPS',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Tab Selector (YouTube vs Local Video)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              index: 0,
                              title: 'YouTube URL',
                              icon: Icons.play_circle_fill,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              index: 1,
                              title: 'Local Gallery Video',
                              icon: Icons.file_upload,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Mode 0: YouTube Input
                if (_selectedMode == 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1F2937)),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.link, color: Color(0xFF38BDF8)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _urlController,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Paste YouTube Video / Shorts URL...',
                                      hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isLoadingInfo ? null : _fetchYouTubeInfo,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  child: _isLoadingInfo
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Text(
                                          'Fetch Info',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                          if (_loadedVideo != null) ...[
                            const SizedBox(height: 10),
                            VideoInfoCard(
                              metadata: _loadedVideo!,
                              onClear: () => setState(() => _loadedVideo = null),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Mode 1: Local Video Picker
                if (_selectedMode == 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _pickLocalVideo,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8).withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.video_library_rounded, color: Color(0xFF38BDF8), size: 40),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Tap to Select Video from Phone',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Supports MP4, MOV, MKV, WebM from Gallery',
                                    style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_loadedVideo != null) ...[
                            const SizedBox(height: 10),
                            VideoInfoCard(
                              metadata: _loadedVideo!,
                              onClear: () => setState(() {
                                _loadedVideo = null;
                                _localVideoPath = null;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Speed Curve Presets Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ SPEED CURVE PRESETS',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF38BDF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...SpeedCurvePreset.values.map((preset) => _buildPresetRadioTile(preset)),
                      ],
                    ),
                  ),
                ),

                // Custom Sliders (If Custom is selected or Auto 60s target time)
                if (_selectedPreset == SpeedCurvePreset.auto60s || _selectedPreset == SpeedCurvePreset.custom)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎛️ SPEED & TIMING CONTROLS',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_selectedPreset == SpeedCurvePreset.auto60s) ...[
                              _buildSliderRow(
                                title: 'Target Video Duration',
                                valueText: '${_targetSeconds.toInt()} Seconds',
                                value: _targetSeconds,
                                min: 10,
                                max: 120,
                                onChanged: (v) => setState(() => _targetSeconds = v),
                              ),
                            ],
                            if (_selectedPreset == SpeedCurvePreset.custom) ...[
                              _buildSliderRow(
                                title: 'Start Speed',
                                valueText: '${_startSpeed.toStringAsFixed(2)}x',
                                value: _startSpeed,
                                min: 0.1,
                                max: 4.0,
                                onChanged: (v) => setState(() => _startSpeed = v),
                              ),
                              const SizedBox(height: 10),
                              _buildSliderRow(
                                title: 'End Slow-mo Speed',
                                valueText: '${_endSpeed.toStringAsFixed(2)}x',
                                value: _endSpeed,
                                min: 0.05,
                                max: 2.0,
                                onChanged: (v) => setState(() => _endSpeed = v),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _buildSliderRow(
                              title: 'Slowdown Start Point',
                              valueText: '${_slowdownPoint.toInt()}% of video',
                              value: _slowdownPoint,
                              min: 10,
                              max: 90,
                              onChanged: (v) => setState(() => _slowdownPoint = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Engine Toggles
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: '✨ Smooth 60 FPS (Motion Interpolation)',
                            subtitle: 'Ultra-silky slow motion without stuttering',
                            value: _smooth60Fps,
                            onChanged: (v) => setState(() => _smooth60Fps = v),
                          ),
                          const Divider(color: Color(0xFF1F2937), height: 24),
                          _buildSwitchTile(
                            title: '🎙️ Preserve Pitch (Natural Voice)',
                            subtitle: 'Keeps human voice natural during slow-mo',
                            value: _preservePitch,
                            onChanged: (v) => setState(() => _preservePitch = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Start Process Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _startProcessing,
                        icon: const Icon(Icons.bolt, color: Colors.white, size: 24),
                        label: Text(
                          '⚡ START AI VIDEO EDITING',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),

            // Real-Time Progress Overlay
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _currentProgress?.stage ?? 'Processing Video...',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_currentProgress?.percent ?? 0) / 100.0,
                            minHeight: 10,
                            backgroundColor: const Color(0xFF1F2937),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_currentProgress?.percent ?? 0).toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF38BDF8),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentProgress?.message ?? 'Please wait...',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: _cancelProcess,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel Process',
                            style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required int index, required String title, required IconData icon}) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMode = index;
        _loadedVideo = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetRadioTile(SpeedCurvePreset preset) {
    final isSelected = _selectedPreset == preset;
    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = preset),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(preset.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                preset.title,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF4B5563),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(color: const Color(0xFFD1D5DB), fontSize: 13)),
            Text(
              valueText,
              style: GoogleFonts.inter(
                color: const Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF38BDF8),
            inactiveTrackColor: const Color(0xFF1F2937),
            thumbColor: const Color(0xFF38BDF8),
            overlayColor: const Color(0xFF38BDF8).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: const Color(0xFF38BDF8),
          activeTrackColor: const Color(0xFF0284C7).withOpacity(0.5),
          inactiveThumbColor: const Color(0xFF9CA3AF),
          inactiveTrackColor: const Color(0xFF1F2937),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
