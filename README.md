# ocr_scanner

A new Flutter project.

## Requirements

Before running the project, ensure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Ensure it is added to your PATH)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / Visual Studio Code (with Flutter & Dart plugins installed)
- An active Android Emulator, iOS Simulator, or connected physical device.

## Getting Started

To get the app up and running on your local machine, follow these steps:

### 1. Clone the repository
```bash
git clone https://github.com/juweriya13/wafers-app-frontend.git
cd wafers-app-frontend
```

### 2. Install Dependencies
Run the following command to download all the required packages:
```bash
flutter pub get
```

### 3. Add Environment & Configuration Files
For security reasons, sensitive files are not included in the GitHub repository. **You must manually obtain these files from the project owner and place them in the correct directories:**

- **`.env`**: Place this file in the root folder of the project.
- **`google-services.json`** (For Firebase Android): Place this file inside `android/app/`.
- **`GoogleService-Info.plist`** (For Firebase iOS): Place this file inside `ios/Runner/`.

*(Note: If you do not have these files, the app might crash or fail to build!)*

### 4. Run the App
Once everything is configured and your emulator/device is connected, run:
```bash
flutter run
```
