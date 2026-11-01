# Caffeine Cafe — Flutter Ordering App

A polished coffee-shop ordering application built with **Flutter and Dart**. The project is maintained as a standalone repository and is suitable as a Flutter portfolio project.

## Features

- Browse coffee drinks with product images and Omani Rial prices
- Search by drink name or description
- Filter the menu by Espresso, Latte, Cold, and Brew categories
- View product details and add drinks to the cart
- Adjust quantities, remove items, and calculate the subtotal
- Place a pickup order with customer details
- Review order history and current order status
- Persist orders and staff status changes locally between app launches
- Open a staff dashboard with order counts, total order value, and status management
- Responsive Material 3 interface with empty states and image fallbacks

## Technology

- Flutter and Dart
- Material 3
- ChangeNotifier for cart and order state
- SharedPreferences for device-local persistence
- Flutter widget and unit tests
- GitHub Actions for formatting, static analysis, tests, and a web release build

## Run the app

### Requirements

- Flutter SDK (stable channel) and its bundled Dart SDK
- Android Studio and Android SDK for Android emulators/devices, or Chrome for web

### Setup

Run these commands from the repository root:

```bash
flutter create . --platforms=android,web --project-name=caffeine_cafe_mobile
flutter pub get
```

Run on a connected Android device/emulator:

```bash
flutter run
```

Run in Chrome:

```bash
flutter run -d chrome
```

## Quality checks

```bash
dart format lib test
flutter analyze
flutter test
flutter build web --release
```

The GitHub Actions workflow runs these checks on every push and pull request. It generates the platform runner folders in the CI environment before running the checks.

## Project structure

```text
lib/
├── data/
│   └── coffee_menu.dart
├── models/
│   ├── cafe_order.dart
│   └── coffee.dart
├── services/
│   └── order_storage.dart
├── state/
│   ├── cart_store.dart
│   └── order_store.dart
└── main.dart

test/
├── cart_store_test.dart
├── order_store_test.dart
└── widget_test.dart

backend/
└── supabase/
    ├── README.md
    └── schema.sql
```

## Persistence and backend scope

The app runs without Firebase or a paid backend. The menu and cart are local to the app. Orders and staff status changes are stored on the current device using SharedPreferences, so they survive app restarts on that device. **They are not synchronized across multiple phones or with an external website.**

Checkout is a demonstration pickup flow and does **not** process payments. The Supabase schema in [backend/supabase/](backend/supabase/) is a backend foundation only; the Flutter app is **not connected to Supabase yet**. Review its README before applying it to a real project.

## Recommended next steps

1. Connect Supabase Auth and menu/order APIs.
2. Add staff authentication and enforce role-based access.
3. Add Realtime updates so customer and staff devices share order state.
4. Integrate a payment provider before accepting online payments.
5. Add screenshots from Android and web runs to document the UI.
