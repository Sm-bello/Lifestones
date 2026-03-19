# Lifestones Church App

> "Where iron sharpens iron" — Proverbs 27:17

A premium discipleship and community app built for Nigerian church networks.
Designed to work on 3G with minimal data usage.

---

## About

Lifestones replaces WhatsApp/Telegram voice calls for church discipleship classes.
Built for Lifestones Teens & Young Adults ministry, designed to scale to other African churches.

Classes: Friday, Saturday & Sunday at 6:00 PM

---

## Features

### Discover
- Daily Bible reading plan
- Scripture carousel (auto-scrolling, hold to pause)
- Upcoming class schedule
- Past class recordings with play and download

### The Sanctuary
- Start/join live audio classes (Jitsi - meet.ffmuc.net)
- Data saver engine - stable on 100MB/3G
- Real-time LIVE indicator visible to all members instantly
- Pastor-only: start class, end class, record session
- Schedule future classes with topic and time

### Members
- Full church directory with profiles
- Search by name
- View bio, phone number, role badge

### Community Chat
- Real-time messaging
- Pastor approval required to chat
- Typing indicators
- Scripture detection - gold card display
- Pastor can approve/reject/remove members

### Prayer Requests
- Members post prayer needs
- Pastor responds publicly
- Mark prayers as answered

### Profile
- Edit name, bio, phone number
- Upload profile photo
- Role badge (Pastor / Member)
- Pastor dashboard - attendance records and chat approvals
- Auto-update banner when new version available

---

## Security

- Google Sign-in required - no anonymous access
- Role selection on first login (Pastor / Member)
- Pastor PIN stored in Firebase - not hardcoded
- Chat access requires Pastor approval
- Sign out returns to Google login screen

---

## Tech Stack

- Framework: Flutter 3.41.4
- Voice Calls: Jitsi Meet SDK 11.6.0 (meet.ffmuc.net)
- Auth: Firebase Auth (Google Sign-in)
- Database: Cloud Firestore (real-time)
- Storage: Firebase Storage (recordings, photos)
- Notifications: FCM + flutter_local_notifications
- Recording: flutter_sound (Pastor device)
- CI/CD: GitHub Actions
- Build: Split APK - arm64, armeabi-v7a, x86_64

---

## Installation

### For Church Members
Download the APK from your Pastor via WhatsApp:
- Most phones (2017+): Lifestones-arm64-v8a.apk (~64MB)
- Older phones: Lifestones-armeabi-v7a.apk (~53MB)

### For Developers
    git clone https://github.com/Sm-bello/Lifestones.git
    cd Lifestones
    flutter pub get
    flutter run

---

## Project Structure

    lib/
    main.dart                 All screens
    firebase_service.dart     All Firestore operations
    firebase_options.dart     Firebase configuration
    notification_service.dart FCM + local notifications

    ci/
    build.gradle.kts          Pre-written Gradle config
    AndroidManifest.xml       Jitsi-compatible manifest
    MainActivity.kt           FlutterFragmentActivity
    strings.xml               App name resource
    ic_launcher_*.png         App icons (all densities)

---

## Roadmap

Shipped:
- Audio streaming (Jitsi - voice only)
- Real-time chat with approval system
- Prayer requests with Pastor responses
- Attendance tracking
- Daily Bible reading plan
- Class recording and playback
- Scheduled class reminders
- Auto-update system via Firestore

Next:
- AI sermon summaries (Whisper API)
- Worship song lyrics display
- Full offline mode
- WhatsApp notification bot (Twilio)

Future:
- Multi-church support
- Tithe and offering (Paystack)
- Google Play Store release

---

## Firebase Setup

Required Firestore documents:
- app_config/security - pastor_pin: "YOUR_PIN"
- app_config/version - latest_version: "1.0.0", download_url: ""

---

## Built By

Mohammed Bello Sani
Final Year Aerospace Engineering, AFIT Kaduna
https://smbello.vercel.app

Built with love for the Lifestones family - Abuja, Nigeria
