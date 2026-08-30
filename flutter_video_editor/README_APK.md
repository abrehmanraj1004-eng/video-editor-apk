# 📱 AbdulRehman Video Editor - Mobile APK Guide (Urdu / English)

Yeh project **AbdulRehman Video Editor** ka complete native Android Mobile App (Flutter + Mobile FFmpeg + On-Device YouTube Downloader) hai.

Yeh app **100% On-Device** kaam karti hai — yani kisi computer ya external server ki zaroorat nahi hai. YouTube downloading, speed curve calculations, 60fps interpolation aur phone gallery saving sab mobile ke andar hi hota hai.

---

## 🚀 APK Hasil Karne ke 2 Aasan Tareeqe:

### ⭐ Tareeqa 1: GitHub Actions se 2 Minute me Free APK Download Karein (Recommended - No PC Setup Needed!)

Aapke PC par Flutter ya Android Studio install karne ki zaroorat nahi hai. GitHub ka cloud server 2 minute me aapko ready-to-install `.apk` bana kar dega:

1. [GitHub.com](https://github.com) par ek free account banayein aur ek **New Repository** banayein.
2. Iss project folder ko apne GitHub repository me upload / push karein:
   ```bash
   git init
   git add .
   git commit -m "Add mobile app"
   git branch -M main
   git remote add origin https://github.com/AAPKA_USERNAME/AAPKA_REPO_NAME.git
   git push -u origin main
   ```
3. Apne GitHub Repository ke **"Actions"** tab par jayein.
4. Wahan **"Build Android Release APK"** workflow automatically start ho jayega.
5. 2 se 3 minute baad build complete ho jayegi aur **Artifacts** section se `AbdulRehman-VideoEditor-APK.zip` download karke apne Android mobile me install kar lein!

---

### ⭐ Tareeqa 2: Apne Computer Par Local APK Build Karna (If you have Flutter)

Agar aapke computer par Flutter aur Android Studio installed hain:

1. Terminal me `flutter_video_editor` folder me jayein:
   ```bash
   cd "flutter_video_editor"
   ```
2. Packages install karein:
   ```bash
   flutter pub get
   ```
3. Release APK generate karein:
   ```bash
   flutter build apk --release
   ```
4. Output APK file aapko yahan milegi:
   `flutter_video_editor/build/app/outputs/flutter-apk/app-release.apk`
5. Is file ko apne phone me send karein aur Install kar lein!

---

## ✨ Features Summary:
- **YouTube Link & Shorts Downloader:** Direct 1080p/720p/480p on-device stream downloader.
- **Local Video Picker:** Phone gallery se koi bhi MP4/MOV video select karein.
- **6 AI Speed Curve Presets:**
  - 🎯 **Auto 60s:** Agar video 60s se choti hai to aakhir se smooth slow-mo karke exact 60s banata hai.
  - ⚡ **CapCut Flash-Out (Slow-mo End)**
  - 🦸 **Hero / Bullet Ramp**
  - 💥 **Flash In**
  - 🎵 **Montage Rhythm**
  - ⚙️ **Custom Speed Sliders (Start/End Speed, Transition Point, Target Duration)**
- **Smooth 60 FPS (Motion Interpolation):** Silky smooth high-fps rendering.
- **Preserve Pitch:** Slow-motion ke doran awaz natural rehti hai.
- **In-App Player & Gallery Saver:** Video preview chala kar 1-tap me phone ki Photos/Gallery me save karein.
