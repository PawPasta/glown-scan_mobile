# GlowScan Mobile

GlowScan Mobile is the Flutter client for GlowScan, a personalized skincare
application. It is intended to connect to the GlowScan Backend for accounts,
profiles, and future skincare features.

> **Current status:** The app has a three-page first-launch onboarding flow.
> Login, registration, and password-reset screens are connected to the backend.
> Skincare features are not yet implemented; onboarding introduces planned
> capabilities without presenting them as available features.

## Flutter app structure

The current onboarding follows the feature-first structure planned for the app:

```text
lib/
├── features/
│   ├── auth/
│   │   ├── pages/
│   │   └── services/
│   ├── home/
│   ├── notifications/
│   │   └── services/
│   │       └── push_notification_service.dart
│   └── onboarding/
│       ├── pages/
│       └── services/
├── core/
│   ├── network/
│   │   ├── api_client.dart
│   │   └── api_endpoints.dart
│   └── storage/
│       └── auth_session_storage.dart
└── main.dart
```

The onboarding appears on first launch, supports swiping and skipping, and
stores its completion state locally. The remaining `config/`, `components/`,
`theme/`, and product feature folders can be added as those parts are built.

## Push notifications

Firebase is initialized when the app starts. On Android and iOS, the app requests
notification permission and retrieves the FCM registration token. Read the
current token from `PushNotificationService.instance.fcmToken` after
initialization, and use `PushNotificationService.instance.onTokenRefresh` to
handle token changes and update the backend. Tokens are not logged or persisted
by the app.

Android uses `android/app/google-services.json` and requests the Android 13+
notification permission. For iOS, register the matching bundle ID
(`com.example.glownScanMobile`) in Firebase, configure an APNs authentication
key in Firebase Console, and enable the Push Notifications capability for the
Runner target in Xcode. A valid APNs configuration and device provisioning are
required to obtain an iOS FCM token.

The onboarding illustrations currently use Flutter Material icons as
placeholders. When custom artwork is ready, add it under
`assets/images/onboarding/`, register the directory in `pubspec.yaml`, and
replace the placeholder icons in `onboarding_page.dart`.

## Product flows

The mobile experience is planned around these user journeys:

1. **Account and personalization** — register or sign in, verify an email when
   using password authentication, complete a skin profile, and view a
   personalized home.
2. **Skin analysis** — capture or select a facial image, review the result,
   and revisit analysis history and changes over time.
3. **Routine and products** — follow morning/evening routine steps and explore
   product recommendations based on the user's skin profile.
4. **Premium** — view plans and manage verified purchases and premium features.

The current backend supports authentication, personal and skin profiles, and
avatar uploads. Skin analysis workflows, routine tracking, recommendations,
subscriptions, and product catalog APIs are not yet available to the mobile
client. Do not present those flows as working features until their backend
contracts and Flutter implementations are in place.

## Backend API contract

The API currently listens on port `3000` by default and does not use a global
`/api` path prefix. Successful responses use this envelope:

```json
{
  "status": 200,
  "message": "Success",
  "data": {}
}
```

Errors use the same envelope with `data: null`; clients should also handle the
HTTP status code. Request bodies are validated and unknown fields are rejected.

### Authentication

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/auth/register` | Register with `email`, `password`, and `confirmPassword`; the account awaits email verification. |
| `POST` | `/auth/verify-email` | Verify with `email` and the one-time `token`. |
| `POST` | `/auth/verify-email/check` | Check whether a website-used email verification token succeeded, using `email` and `token`. |
| `POST` | `/auth/verify-email/resend` | Resend the email verification message using `email`. |
| `POST` | `/auth/mobile/login` | Sign in with `email`, `password`, `platform` (`ANDROID`/`IOS`), and `fcmToken`; the token is saved with the login session. |
| `POST` | `/auth/firebase/login` | Exchange a Firebase ID token for GlowScan access and refresh tokens. |
| `POST` | `/auth/refresh` | Rotate the refresh token using both `accessToken` and `refreshToken`. |
| `POST` | `/auth/logout` | Revoke the refresh-token family using `refreshToken`. |
| `POST` | `/auth/password/reset/request` | Request a reset email; the response does not reveal account existence. |
| `POST` | `/auth/password/reset/check` | Check whether a website-used password-reset token succeeded, using `email` and `token`. |
| `POST` | `/auth/password/reset/resend` | Send a new reset email using `email`; invalidates any unused previous reset token. |
| `POST` | `/auth/password/reset/confirm` | Reset with `email`, `token`, and `newPassword`. |
| `POST` | `/auth/password/change` | Change password with a bearer access token and `oldPassword`/`newPassword`. |

Password authentication requires at least six characters, including an
uppercase letter, a lowercase letter, a number, and a special character.
Passwords must not exceed 72 UTF-8 bytes. Verification, reset, and refresh
tokens are secrets: never log them, and store refresh credentials in the
platform's secure storage rather than ordinary preferences.

Website-used email verification and reset tokens can be checked in the app;
the check endpoints return `data.success`. Verification tokens expire after
24 hours, while password-reset tokens expire after 1 hour.

For Firebase sign-in, the client sends `{ "idToken": "..." }` to
`/auth/firebase/login`. An optional `platform` is one of `ANDROID` or `IOS`
(the backend also accepts `WEBSITE`). The backend verifies the ID token and
requires a verified email; the client must not send a device UUID because the
backend creates one for each login session.

### Profile

All profile endpoints require `Authorization: Bearer <accessToken>`.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/profile` | Read personal and skin profile data. |
| `PATCH` | `/profile` | Update `fullName`, `dateOfBirth`, or `gender`. |
| `PATCH` | `/profile/skin` | Update `skinType`, `sensitivityLevel`, or `notes`. |
| `POST` | `/profile/avatar/upload-intent` | Request signed metadata for an avatar upload. |
| `POST` | `/profile/avatar/confirm` | Confirm a completed Cloudinary upload. |

Omitted patch fields remain unchanged; nullable fields may be set to `null` to
clear them. Allowed values include `MALE`, `FEMALE`, `OTHER`, and
`PREFER_NOT_TO_SAY` for gender; `NORMAL`, `DRY`, `OILY`, and `COMBINATION` for
skin type; and `LOW`, `MEDIUM`, and `HIGH` for sensitivity.

Avatar uploads use a two-step flow: request an upload intent, upload directly
to Cloudinary using the returned signed parameters, then confirm with
`publicId`, `version`, `signature`, and `secureUrl` (map these from Cloudinary's
`public_id` and `secure_url` response fields). Intents expire after 10 minutes
and can only be used once.

## Configuration and environments

### API base URL

The API base URL is loaded by `flutter_dotenv` from `.env.local`. Copy
`.env.example` to `.env.local` and set `API_BASE_URL`; the default points to
`https://api.glownscan.xyz`. The local file is ignored by Git but bundled as a
Flutter asset, so it must exist before running or building the app. This URL is
public client configuration, not a place for secrets.

API calls are implemented in `lib/features/auth/services/auth_api.dart` and
use `lib/core/network/api_client.dart`. Override `API_BASE_URL` for local
development with a URL reachable from the device (for example,
`http://10.0.2.2:3000` for an Android emulator or
`http://<computer-LAN-IP>:3000` for a physical device).

Backend paths are centralized in `lib/core/network/api_endpoints.dart`. The
generic API client supports GET, POST, PUT, PATCH, and DELETE, JSON request
bodies, and the `{status, message, data}` response envelope. Set
`requiresAuth: true` or pass `accessToken` to attach a Bearer token; protected
requests read the access token from `flutter_secure_storage` by default.

The app opens Login after onboarding. Login sends the Android platform and the
current FCM token to `/auth/mobile/login`; successful access/refresh tokens
are saved in secure storage. Register and password-reset pages show backend
messages, support resending emails, and allow checking a reset token received
by email.

### Firebase

Firebase sign-in is verified by the backend against
`GLOWNSCAN_FIREBASE_PROJECT_ID`. Configure the Flutter Firebase client for the
same Firebase project, using platform-specific Firebase configuration for
Android and iOS. Firebase is initialized in `main.dart` before app startup.

Firebase client configuration is not a substitute for backend verification.
Never put Firebase Admin credentials, database URLs, JWT signing secrets,
SMTP passwords, Cloudinary API secrets, or Gemini API keys in the Flutter app.
Those values belong only in the backend's protected environment.

Email verification and password-reset links are currently composed by the
backend from `GLOWNSCAN_FRONTEND_URL`,
`GLOWNSCAN_EMAIL_VERIFY_PATH`, and `GLOWNSCAN_PASSWORD_RESET_PATH`. A mobile
deep-link flow will need an agreed callback/deep-link contract before the app
can complete those flows directly.

## Run the Flutter app

Requirements: Flutter SDK with Dart support, and a configured Android or iOS
device/emulator.

```bash
flutter pub get
flutter run
```

The first-launch onboarding and the login, registration, and password-reset
flows are implemented. Skincare screens are not wired up yet.

## Design system

The mobile UI follows the GlowScan Pink Editorial design system documented in
[`docs/design/CLAUDE.md`](docs/design/CLAUDE.md), adapted from the website for
touch-first layouts. Shared Flutter color, typography, form, and button tokens
are defined in `lib/core/theme/app_theme.dart`.

## Related backend documentation

The backend repository is a sibling directory in the GlowScan workspace:

- [Backend README](../glown-scan_be/README.md) — backend setup, environment
  variables, database migrations, and operational details.
- [Backend code structure](../glown-scan_be/docs/architecture/CODE_STRUCTURE.md)
  — backend modules and request flow.
