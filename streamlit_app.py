import os
import sys
import tempfile
import time
import streamlit as st

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
if os.path.exists("web_video_editor"):
    sys.path.insert(0, os.path.abspath("web_video_editor"))
if os.path.exists("anti gravity - Copy"):
    sys.path.insert(0, os.path.abspath("anti gravity - Copy"))

import video_processor

# Page Configuration
st.set_page_config(
    page_title="AbdulRehman Video Editor",
    page_icon="🎬",
    layout="centered",
    initial_sidebar_state="collapsed"
)

# Custom Dark Theme Styling
st.markdown("""
<style>
    .stApp {
        background-color: #0B0F19;
        color: #F9FAFB;
        font-family: 'Inter', sans-serif;
    }
    .main-header {
        background: linear-gradient(135deg, #111827 0%, #172033 100%);
        border: 1.5px solid #1F2937;
        border-radius: 16px;
        padding: 16px 20px;
        margin-bottom: 20px;
        display: flex;
        align-items: center;
        gap: 16px;
    }
    .header-title {
        color: #38BDF8;
        font-size: 22px;
        font-weight: 800;
        margin: 0;
    }
    .header-subtitle {
        color: #9CA3AF;
        font-size: 12px;
        margin: 0;
    }
    .pro-badge {
        background-color: #38BDF8;
        color: #0B0F19;
        padding: 2px 8px;
        border-radius: 6px;
        font-size: 10px;
        font-weight: 900;
        margin-left: 8px;
    }
    .stButton>button {
        background: linear-gradient(135deg, #0284C7 0%, #0369A1 100%);
        color: white;
        font-weight: 700;
        border: none;
        border-radius: 12px;
        padding: 12px 24px;
        width: 100%;
        box-shadow: 0 4px 14px rgba(2, 132, 199, 0.4);
    }
</style>
""", unsafe_allow_html=True)

# Header
st.markdown("""
<div class="main-header">
    <div style="font-size: 32px; background: rgba(2,132,199,0.2); padding: 8px; border-radius: 12px;">🎬</div>
    <div>
        <div style="display: flex; align-items: center;">
            <h1 class="header-title">AbdulRehman Editor</h1>
            <span class="pro-badge">PRO AI</span>
        </div>
        <p class="header-subtitle">AI Speed Curve • Auto 60s • 60 FPS Motion Interpolation</p>
    </div>
</div>
""", unsafe_allow_html=True)

# Input Mode Tabs
tab1, tab2 = st.tabs(["▶️ YouTube Video / Shorts", "📁 Upload Local Video"])

input_video_path = None
video_title = "Edited Video"

with tab1:
    yt_url = st.text_input("Paste YouTube URL:", placeholder="https://www.youtube.com/watch?v=... or shorts URL")
    if yt_url:
        if st.button("🔍 Fetch Video Info"):
            with st.spinner("Fetching YouTube details..."):
                try:
                    info = video_processor.get_video_info_from_url(yt_url.strip())
                    st.success(f"**{info['title']}** (⏱️ {info['duration_formatted']}) by {info['uploader']}")
                    if info.get('thumbnail'):
                        st.image(info['thumbnail'], width=280)
                except Exception as e:
                    st.error(f"Error: {e}")

with tab2:
    uploaded_file = st.file_uploader("Upload Video (MP4, MOV, MKV):", type=["mp4", "mov", "mkv", "webm"])
    if uploaded_file:
        tfile = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
        tfile.write(uploaded_file.read())
        input_video_path = tfile.name
        video_title = uploaded_file.name
        st.video(input_video_path)

st.markdown("---")

# Speed Curve Preset
st.subheader("⚡ Speed Curve Presets")
preset_options = {
    "🎯 Auto 60s (Slowdown End if <60s, Keep if >=60s)": "auto_60s",
    "⚡ CapCut Flash-Out (Smooth Slow-mo End)": "end_slowdown",
    "🦸 Hero / Bullet Ramp (1.5x -> 0.25x -> 1.4x)": "hero_bullet",
    "💥 Flash In (0.25x Slow Start -> 1.5x Fast Finish)": "flash_in",
    "🎵 Montage Rhythm (Fast -> Slow -> Fast -> Slow)": "montage",
    "⚙️ Custom Speed Warp & Sliders": "custom"
}

selected_preset_label = st.radio("Choose Preset:", list(preset_options.keys()))
preset_key = preset_options[selected_preset_label]

# Sliders
target_duration = 60.0
start_speed = 1.0
end_speed = 0.22
slowdown_point = 60.0

if preset_key == "auto_60s":
    target_duration = st.slider("Target Video Duration (Seconds):", min_value=10, max_value=120, value=60)
elif preset_key == "custom":
    col1, col2 = st.columns(2)
    with col1:
        start_speed = st.slider("Start Speed:", min_value=0.1, max_value=3.0, value=1.0, step=0.05)
    with col2:
        end_speed = st.slider("End Slow-mo Speed:", min_value=0.05, max_value=2.0, value=0.22, step=0.01)

slowdown_point = st.slider("Slowdown Transition Point (% of video):", min_value=10, max_value=90, value=60)

# Settings
col_s1, col_s2 = st.columns(2)
with col_s1:
    smooth_fps = st.checkbox("✨ Smooth 60 FPS (Motion Interpolation)", value=True)
with col_s2:
    preserve_pitch = st.checkbox("🎙️ Preserve Natural Voice Pitch", value=True)

st.markdown("---")

# Process Button
if st.button("⚡ START AI VIDEO EDITING"):
    if not input_video_path and not yt_url:
        st.warning("Please provide a YouTube URL or upload a video file first.")
    else:
        progress_bar = st.progress(0)
        status_text = st.empty()
        
        output_dir = tempfile.mkdtemp()
        output_path = os.path.join(output_dir, "final_edited.mp4")

        try:
            # Download YouTube if needed
            if not input_video_path and yt_url:
                status_text.info("📥 Downloading YouTube stream...")
                
                def dl_progress(d):
                    pct = int(d.get('percent', 0))
                    progress_bar.progress(min(max(pct, 0), 50))
                    status_text.text(d.get('message', 'Downloading...'))

                input_video_path = video_processor.download_youtube_video(
                    url=yt_url.strip(),
                    output_dir=output_dir,
                    progress_callback=dl_progress
                )

            status_text.info("⚡ Rendering AI Speed Curve & 60 FPS Interpolation...")
            progress_bar.progress(60)

            custom_params = {
                'start_speed': start_speed,
                'end_speed': end_speed,
                'split_percent': slowdown_point,
                'target_duration': float(target_duration)
            }

            video_processor.apply_speed_curve(
                input_video_path=input_video_path,
                output_video_path=output_path,
                preset=preset_key,
                custom_params=custom_params,
                audio_mode='keep_pitch' if preserve_pitch else 'none',
                smooth_fps=smooth_fps
            )

            progress_bar.progress(100)
            status_text.success("🎉 Video Processed Successfully!")

            # Playback
            st.video(output_path)

            # Download Button
            with open(output_path, "rb") as file:
                st.download_button(
                    label="💾 Download Processed Video",
                    data=file,
                    file_name="AbdulRehman_Edited_Video.mp4",
                    mime="video/mp4"
                )

        except Exception as e:
            st.error(f"Processing Error: {e}")
