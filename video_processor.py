import os
import sys
import subprocess
import json
import re
import math
import shutil
import yt_dlp

def format_time(seconds):
    """Format seconds into HH:MM:SS or MM:SS."""
    if seconds is None:
        return "00:00"
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"

def get_ffprobe_path():
    """Find ffprobe executable if available, fallback to ffmpeg."""
    ffprobe_cmd = shutil.which("ffprobe")
    if ffprobe_cmd:
        return ffprobe_cmd
    ffmpeg_cmd = shutil.which("ffmpeg")
    if ffmpeg_cmd:
        probe_path = os.path.join(os.path.dirname(ffmpeg_cmd), "ffprobe.exe" if sys.platform == "win32" else "ffprobe")
        if os.path.exists(probe_path):
            return probe_path
    return "ffprobe"

def get_ffmpeg_path():
    """Find ffmpeg executable."""
    cmd = shutil.which("ffmpeg")
    return cmd if cmd else "ffmpeg"

def get_video_info_from_url(url):
    """
    Extract YouTube video information (title, duration, thumbnail, author) without downloading.
    """
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'skip_download': True,
        'extractor_args': {'youtube': {'player_client': ['android', 'ios', 'web']}},
        'nocheckcertificate': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return {
            'title': info.get('title', 'Unknown Title'),
            'duration': info.get('duration', 0),
            'duration_formatted': format_time(info.get('duration', 0)),
            'thumbnail': info.get('thumbnail', ''),
            'uploader': info.get('uploader', 'Unknown Creator'),
            'view_count': info.get('view_count', 0),
            'id': info.get('id', '')
        }

def download_youtube_video(url, output_dir, resolution='best', progress_callback=None, cancel_check=None):
    """
    Download YouTube video to output_dir with progress tracking and robust fallback.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Clean any stale .part or .ytdl files that cause HTTP 416 range error
    try:
        for f in os.listdir(output_dir):
            if f.endswith('.part') or f.endswith('.ytdl'):
                try:
                    os.remove(os.path.join(output_dir, f))
                except Exception:
                    pass
    except Exception:
        pass

    downloaded_file = []

    def hook(d):
        if cancel_check and cancel_check():
            raise Exception("Download cancelled by user.")
        
        if d['status'] == 'downloading':
            total = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
            downloaded = d.get('downloaded_bytes', 0)
            speed = d.get('speed', 0)
            eta = d.get('eta', 0)
            
            percent = (downloaded / total * 100) if total > 0 else 0
            speed_mb = (speed / (1024 * 1024)) if speed else 0
            
            if progress_callback:
                progress_callback({
                    'status': 'downloading',
                    'percent': percent,
                    'speed_mb': speed_mb,
                    'eta': eta,
                    'downloaded_mb': downloaded / (1024 * 1024),
                    'total_mb': total / (1024 * 1024),
                    'message': f"Downloading: {percent:.1f}% ({speed_mb:.2f} MB/s, ETA: {eta}s)"
                })
        elif d['status'] == 'finished':
            filename = d.get('filename')
            if filename:
                downloaded_file.append(filename)
            if progress_callback:
                progress_callback({
                    'status': 'processing',
                    'percent': 100,
                    'message': "Download complete. Processing video..."
                })

    # Robust format selection with multi-stream and single-stream fallbacks
    if resolution == '1080':
        fmt = 'bv*[height<=1080]+ba/b[height<=1080]/best'
    elif resolution == '720':
        fmt = 'bv*[height<=720]+ba/b[height<=720]/best'
    elif resolution == '480':
        fmt = 'bv*[height<=480]+ba/b[height<=480]/best'
    else:
        fmt = 'bv*+ba/b/best'

    out_template = os.path.join(output_dir, '%(title).80s [%(id)s].%(ext)s')

    ydl_opts = {
        'format': fmt,
        'outtmpl': out_template,
        'merge_output_format': 'mp4',
        'progress_hooks': [hook],
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'extractor_args': {'youtube': {'player_client': ['android', 'ios', 'web']}},
        'retries': 10,
        'fragment_retries': 10,
        'http_chunk_size': 10485760,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        final_filename = ydl.prepare_filename(info)
        base, _ = os.path.splitext(final_filename)
        final_mp4 = base + ".mp4"
        if os.path.exists(final_mp4):
            return final_mp4
        if os.path.exists(final_filename):
            return final_filename
        if downloaded_file and os.path.exists(downloaded_file[0]):
            return downloaded_file[0]
        return final_filename

def get_video_metadata(file_path):
    """
    Get duration, resolution, fps, has_audio for local video file using ffprobe/ffmpeg.
    """
    ffprobe = get_ffprobe_path()
    cmd = [
        ffprobe,
        "-v", "error",
        "-show_entries", "format=duration:stream=codec_type,width,height,r_frame_rate,duration",
        "-of", "json",
        file_path
    ]
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        data = json.loads(res.stdout)
        
        duration = float(data.get('format', {}).get('duration', 0))
        width = 0
        height = 0
        fps = 30.0
        has_audio = False

        for stream in data.get('streams', []):
            if stream.get('codec_type') == 'video':
                width = int(stream.get('width', 0) or 0)
                height = int(stream.get('height', 0) or 0)
                r_fps = stream.get('r_frame_rate', '30/1')
                if '/' in r_fps:
                    num, den = r_fps.split('/')
                    if float(den) > 0:
                        fps = float(num) / float(den)
                if duration == 0 and 'duration' in stream:
                    duration = float(stream['duration'])
            elif stream.get('codec_type') == 'audio':
                has_audio = True

        return {
            'duration': duration,
            'duration_formatted': format_time(duration),
            'width': width,
            'height': height,
            'fps': fps,
            'has_audio': has_audio
        }
    except Exception as e:
        # Fallback to ffmpeg -i parsing
        ffmpeg = get_ffmpeg_path()
        cmd = [ffmpeg, "-i", file_path]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out = p.stderr
        duration = 0.0
        dur_match = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.\d+)", out)
        if dur_match:
            h, m, s = dur_match.groups()
            duration = int(h) * 3600 + int(m) * 60 + float(s)
        has_audio = "Audio:" in out
        return {
            'duration': duration,
            'duration_formatted': format_time(duration),
            'width': 1920,
            'height': 1080,
            'fps': 30.0,
            'has_audio': has_audio
        }

def build_atempo_filter(speed):
    """
    Constructs FFmpeg atempo chain because atempo only supports 0.5 to 100.0.
    For example: 0.25x -> atempo=0.5,atempo=0.5
                 0.125x -> atempo=0.5,atempo=0.5,atempo=0.5
                 2.0x -> atempo=2.0
    """
    if speed <= 0:
        speed = 0.1
    filters = []
    current = speed
    while current < 0.5:
        filters.append("atempo=0.5")
        current /= 0.5
    while current > 2.0:
        filters.append("atempo=2.0")
        current /= 2.0
    filters.append(f"atempo={current:.4f}")
    return ",".join(filters)

def calculate_auto_target_duration_segments(duration, target_duration=60.0, slowdown_start_pct=0.60):
    """
    Calculates CapCut curve segments so that a video shorter than target_duration (e.g. 60s)
    is smoothly slowed down at the end to make the total output length EXACTLY target_duration.
    
    If duration >= target_duration, returns a single 1.0x segment (no change).
    """
    if duration >= target_duration - 0.05:
        return [{'start': 0.0, 'end': duration, 'speed': 1.0}], False

    # Stage 1: 0 to p1 (e.g. 50% of video) -> 1.0x (normal speed)
    # Stage 2: p1 to p2 (e.g. 50% to 70% of video) -> smooth transition ramp
    # Stage 3: p2 to duration (e.g. 70% to 100% of video) -> slow_factor
    
    p1 = max(0.0, (slowdown_start_pct - 0.15)) * duration
    p2 = min(0.98, slowdown_start_pct) * duration
    
    t_normal = p1
    t_ramp = p2 - p1
    t_slow = duration - p2
    
    # Solve for s_end using binary search in (0.01, 1.0)
    low = 0.01
    high = 0.9999
    
    for _ in range(60):
        mid = (low + high) / 2.0
        ramp_speed = (1.0 + mid) / 2.0
        out_dur = t_normal + (t_ramp / ramp_speed) + (t_slow / mid)
        if out_dur > target_duration:
            low = mid
        else:
            high = mid
            
    s_end = (low + high) / 2.0
    ramp_spd = (1.0 + s_end) / 2.0
    
    segments = [
        {'start': 0.0, 'end': p1, 'speed': 1.0},
        {'start': p1, 'end': p2, 'speed': ramp_spd},
        {'start': p2, 'end': duration, 'speed': s_end}
    ]
    
    valid_segments = [s for s in segments if s['end'] > s['start'] + 0.01]
    return valid_segments, True

def calculate_curve_segments(duration, preset='auto_60s', custom_params=None):
    """
    Calculates time segments and speeds based on CapCut curve speed ramping.
    Returns list of dicts: [{'start': t0, 'end': t1, 'speed': s}, ...]
    """
    if duration <= 0:
        duration = 10.0 # fallback

    segments = []

    if preset == 'auto_60s':
        target_dur = custom_params.get('target_duration', 60.0) if custom_params else 60.0
        split_pct = (custom_params.get('split_percent', 60) if custom_params else 60) / 100.0
        segs, was_slowed = calculate_auto_target_duration_segments(duration, target_dur, split_pct)
        return segs

    elif preset == 'end_slowdown':
        # CapCut Flash-Out / End Slowdown:
        # 0% - 50%: Normal speed 1.0x
        # 50% - 70%: Smooth ramp 0.65x
        # 70% - 85%: Slow 0.4x
        # 85% - 100%: Dramatic slow-mo 0.2x
        slow_factor = 0.22 if not custom_params else custom_params.get('end_speed', 0.22)
        p1 = 0.50 * duration
        p2 = 0.70 * duration
        p3 = 0.85 * duration
        p4 = duration

        segments = [
            {'start': 0.0, 'end': p1, 'speed': 1.0},
            {'start': p1, 'end': p2, 'speed': (1.0 + slow_factor) * 0.65},
            {'start': p2, 'end': p3, 'speed': slow_factor * 1.6},
            {'start': p3, 'end': p4, 'speed': slow_factor}
        ]

    elif preset == 'hero_bullet':
        # Hero / Bullet: Fast (1.5x) -> Slow climax (0.25x) -> Fast (1.4x) -> Slow end (0.3x)
        p1 = 0.20 * duration
        p2 = 0.35 * duration
        p3 = 0.65 * duration
        p4 = 0.80 * duration
        p5 = duration

        segments = [
            {'start': 0.0, 'end': p1, 'speed': 1.5},
            {'start': p1, 'end': p2, 'speed': 0.7},
            {'start': p2, 'end': p3, 'speed': 0.25},
            {'start': p3, 'end': p4, 'speed': 1.4},
            {'start': p4, 'end': p5, 'speed': 0.35}
        ]

    elif preset == 'flash_in':
        # Flash In: Super slow start (0.25x) -> Ramp up -> High speed finish (1.5x)
        p1 = 0.25 * duration
        p2 = 0.50 * duration
        p3 = duration
        segments = [
            {'start': 0.0, 'end': p1, 'speed': 0.25},
            {'start': p1, 'end': p2, 'speed': 0.7},
            {'start': p2, 'end': p3, 'speed': 1.5}
        ]

    elif preset == 'montage':
        # Montage / Rhythm Curve: Fast -> Slow -> Fast -> Slow
        p1 = 0.25 * duration
        p2 = 0.50 * duration
        p3 = 0.75 * duration
        p4 = duration
        segments = [
            {'start': 0.0, 'end': p1, 'speed': 1.6},
            {'start': p1, 'end': p2, 'speed': 0.3},
            {'start': p2, 'end': p3, 'speed': 1.6},
            {'start': p3, 'end': p4, 'speed': 0.3}
        ]

    elif preset == 'custom':
        start_spd = custom_params.get('start_speed', 1.0) if custom_params else 1.0
        end_spd = custom_params.get('end_speed', 0.25) if custom_params else 0.25
        split_pct = (custom_params.get('split_percent', 60) if custom_params else 60) / 100.0

        p1 = split_pct * 0.85 * duration
        p2 = split_pct * duration
        p3 = duration

        ramp_spd = (start_spd + end_spd) / 2.0

        segments = [
            {'start': 0.0, 'end': p1, 'speed': start_spd},
            {'start': p1, 'end': p2, 'speed': ramp_spd},
            {'start': p2, 'end': p3, 'speed': end_spd}
        ]

    else:
        spd = 0.5
        if custom_params and 'speed' in custom_params:
            spd = custom_params['speed']
        segments = [{'start': 0.0, 'end': duration, 'speed': spd}]

    valid_segments = []
    for seg in segments:
        if seg['end'] > seg['start'] + 0.01:
            valid_segments.append(seg)

    return valid_segments

def apply_speed_curve(input_video_path, output_video_path, preset='end_slowdown', 
                      custom_params=None, audio_mode='keep_pitch', 
                      smooth_fps=True, progress_callback=None, cancel_check=None):
    """
    Applies CapCut-style speed curve to the video using FFmpeg.
    
    audio_mode: 'keep_pitch' (natural pitch preservation), 'mute' (silent), 'none'
    smooth_fps: True to output at smooth 60fps for silky slow motion
    """
    meta = get_video_metadata(input_video_path)
    total_duration = meta['duration']
    has_audio = meta['has_audio'] and (audio_mode != 'mute')
    
    target_dur = custom_params.get('target_duration', 60.0) if custom_params else 60.0
    if preset == 'auto_60s' and total_duration >= target_dur - 0.1:
        if progress_callback:
            progress_callback({
                'status': 'skipped',
                'percent': 100.0,
                'message': f"Video is {total_duration:.1f}s (>= {target_dur:.0f}s). Duration already met, saving original video without slow-mo!"
            })
        shutil.copy2(input_video_path, output_video_path)
        return output_video_path

    segments = calculate_curve_segments(total_duration, preset, custom_params)
    
    # Calculate estimated output duration
    est_output_duration = sum((seg['end'] - seg['start']) / seg['speed'] for seg in segments)

    ffmpeg = get_ffmpeg_path()
    
    # Build filter_complex string
    v_segments = []
    a_segments = []
    filter_parts = []
    
    for i, seg in enumerate(segments):
        start = seg['start']
        end = seg['end']
        speed = seg['speed']
        
        # Video segment: trim, reset PTS, set speed multiplier (1/speed)
        v_name = f"v{i}"
        v_filter = f"[0:v]trim=start={start:.4f}:end={end:.4f},setpts=(PTS-STARTPTS)/{speed:.4f}[{v_name}]"
        filter_parts.append(v_filter)
        v_segments.append(f"[{v_name}]")
        
        # Audio segment
        if has_audio:
            a_name = f"a{i}"
            atempo_str = build_atempo_filter(speed)
            a_filter = f"[0:a]atrim=start={start:.4f}:end={end:.4f},asetpts=PTS-STARTPTS,{atempo_str}[{a_name}]"
            filter_parts.append(a_filter)
            a_segments.append(f"[{a_name}]")

    num_segs = len(segments)
    
    # Concat video
    concat_v = "".join(v_segments) + f"concat=n={num_segs}:v=1:a=0[v_cat]"
    filter_parts.append(concat_v)
    
    final_v_label = "[v_cat]"
    
    # Smooth 60fps filter if enabled
    if smooth_fps:
        filter_parts.append(f"[v_cat]fps=60[v_smooth]")
        final_v_label = "[v_smooth]"

    # Concat audio if present
    final_a_label = ""
    if has_audio:
        concat_a = "".join(a_segments) + f"concat=n={num_segs}:v=0:a=1[a_cat]"
        filter_parts.append(concat_a)
        final_a_label = "[a_cat]"

    filter_complex_str = ";".join(filter_parts)

    # Assemble full FFmpeg command
    cmd = [
        ffmpeg,
        "-y", # overwrite output
        "-i", input_video_path,
        "-filter_complex", filter_complex_str,
        "-map", final_v_label,
    ]
    
    if has_audio:
        cmd.extend(["-map", final_a_label, "-c:a", "aac", "-b:a", "192k"])
    else:
        cmd.extend(["-an"]) # No audio

    # Fast and high quality video encoding (H.264, crf 19, fast preset)
    cmd.extend([
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "19",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        output_video_path
    ])

    # Execute FFmpeg process with stderr monitoring for live progress
    startupinfo = None
    if sys.platform == "win32":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0 # SW_HIDE

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        startupinfo=startupinfo,
        encoding='utf-8',
        errors='replace'
    )

    time_pattern = re.compile(r"time=(\d+):(\d+):(\d+\.\d+)")

    while True:
        if cancel_check and cancel_check():
            process.kill()
            raise Exception("Processing cancelled by user.")

        line = process.stderr.readline()
        if not line and process.poll() is not None:
            break

        if line:
            match = time_pattern.search(line)
            if match and est_output_duration > 0:
                h, m, s = match.groups()
                current_time = int(h) * 3600 + int(m) * 60 + float(s)
                progress_pct = min(99.0, (current_time / est_output_duration) * 100)
                if progress_callback:
                    progress_callback({
                        'status': 'rendering',
                        'percent': progress_pct,
                        'current_time': current_time,
                        'total_time': est_output_duration,
                        'message': f"Rendering CapCut Speed Curve: {progress_pct:.1f}% ({format_time(current_time)} / {format_time(est_output_duration)})"
                    })

    ret_code = process.poll()
    if ret_code != 0:
        err = process.stderr.read()
        raise RuntimeError(f"FFmpeg processing failed (Code {ret_code}): {err[-500:]}")

    if progress_callback:
        progress_callback({
            'status': 'done',
            'percent': 100.0,
            'message': "Video successfully edited and saved!"
        })

    return output_video_path
