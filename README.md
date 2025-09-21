# Admin Flutter App

A Flutter web application with Firebase authentication and Realtime Database integration.

## Features

- Firebase Authentication (commented out for easy configuration)
- Firebase Realtime Database integration (commented out for easy configuration)
- Responsive web design
- Admin dashboard with data management
- Mock data for testing

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Firebase (Optional)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Enable Authentication and Realtime Database
4. Add your web app to the project
5. Download the `firebase_options.dart` file
6. Place it in `lib/firebase_options.dart`
7. Uncomment all the Firebase-related code in:
   - `lib/main.dart`
   - `lib/auth_service.dart`
   - `lib/data_service.dart`

### 3. Run the App

For web development:
```bash
flutter run -d chrome
```

For web build:
```bash
flutter build web
```

## Test Credentials

- Email: admin@test.com
- Password: password

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── auth_service.dart         # Authentication service
├── data_service.dart         # Data management service
└── screens/
    ├── login_screen.dart     # Login page
    └── dashboard_screen.dart # Main dashboard
```

## Notes

- All Firebase connectivity code is commented out
- Mock data is used for testing
- Replace mock implementations with actual Firebase calls when ready
