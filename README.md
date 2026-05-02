# NeedsBridge

An NGO emergency response platform built with Flutter and Firebase.

## Features

- **Emergency Reporting**: Public and field staff can report emergencies
- **AI-Powered Triage**: Automatic priority classification using Gemini AI
- **Volunteer Management**: Smart volunteer assignment based on skills and location
- **Real-time Dashboard**: Role-based dashboards for different user types
- **News Monitoring**: Automated news monitoring for emergency detection
- **Heat Map Visualization**: Geographic visualization of issues in Tamil Nadu

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/Mithun756200/needsbridge.git
cd needsbridge
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure API Keys
Create a `secrets.json` file in `lib/core/services/` with your API keys:

```json
{
  "GEOCODING_API_KEY": "your_google_geocoding_api_key_here",
  "GEMINI_FLUTTER_API_KEY": "your_gemini_api_key_here"
}
```

**Important**: Never commit this file to version control. It's already added to `.gitignore`.

### 4. Firebase Setup
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Firestore Database
3. Enable Authentication (Email/Password)
4. Replace `firebase_options.dart` with your project configuration

### 5. Build and Run
```bash
flutter run -d web --dart-define-from-file=lib/core/services/secrets.json
```

## API Keys Required

- **Google Gemini API**: For AI-powered emergency triage and news parsing
- **Google Geocoding API**: For location services and mapping

## Deployment

### Firebase Hosting
```bash
flutter build web --dart-define-from-file=lib/core/services/secrets.json
firebase deploy
```

## Project Structure

- `lib/core/` - Core services, providers, and routing
- `lib/features/` - Feature-specific screens and widgets
- `lib/shared/` - Shared widgets and utilities

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
