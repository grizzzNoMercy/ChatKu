# ChatKu 💬

Realtime Chat Application with Live Presence System — dibangun dengan Flutter + Firebase.

## ✨ Fitur

| Fitur | Status |
|-------|--------|
| Authentication (Register/Login/Logout) | ✅ |
| Realtime Chat | ✅ |
| Live Online Status | ✅ |
| Live Room Presence | ✅ |
| Typing Indicator | ✅ |
| Kirim Foto | ✅ |
| Kirim Video | ✅ |
| Kirim File (PDF, DOCX, ZIP, TXT) | ✅ |
| Profile Page | ✅ |
| Search User | ✅ |

## 🗂 Struktur Folder

```
lib/
├── main.dart
├── pages/
│   ├── splash_page.dart
│   ├── login_page.dart
│   ├── register_page.dart
│   ├── home_page.dart
│   ├── chat_page.dart
│   └── profile_page.dart
├── services/
│   ├── auth_service.dart
│   ├── chat_service.dart
│   ├── storage_service.dart
│   └── presence_service.dart
├── models/
│   ├── user_model.dart
│   └── message_model.dart
└── widgets/
    ├── chat_bubble.dart
    ├── user_tile.dart
    └── presence_widget.dart
```

## 🚀 Setup

### 1. Buat Firebase Project

1. Buka [Firebase Console](https://console.firebase.google.com)
2. Klik **Add project** → beri nama `ChatKu`
3. Aktifkan **Google Analytics** (opsional)

### 2. Tambahkan Android App

1. Di Firebase Console → **Project Settings** → **Add app** → pilih Android
2. Package name: `com.example.chatku`
3. Download `google-services.json`
4. Letakkan di: `android/app/google-services.json`

### 3. Aktifkan Firebase Services

**Authentication:**
- Firebase Console → Authentication → Sign-in method
- Aktifkan **Email/Password**

**Firestore:**
- Firebase Console → Firestore Database → Create database
- Mulai dengan **production mode**
- Pilih region terdekat (misalnya `asia-southeast2` untuk Jakarta)
- Pergi ke **Rules** → paste isi `firestore.rules`

**Storage:**
- Firebase Console → Storage → Get started
- Pergi ke **Rules** → paste isi `storage.rules`

### 4. Setup timeago Locale Indonesia

Tambahkan di `main.dart` sebelum `runApp()`:

```dart
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  // ...
  timeago.setLocaleMessages('id', timeago.IdMessages());
  runApp(const ChatKuApp());
}
```

### 5. Install Dependencies

```bash
flutter pub get
```

### 6. Jalankan

```bash
flutter run
```

## 📊 Skema Database Firestore

### Collection: `users`
```json
{
  "uid": "string",
  "username": "string",
  "email": "string",
  "photoUrl": "string",
  "online": "boolean",
  "lastSeen": "timestamp",
  "inRoom": "boolean",
  "currentRoom": "string",
  "lastRoomLeave": "timestamp"
}
```

### Collection: `chat_rooms`
```json
{
  "roomId": "uid1_uid2",
  "participants": ["uid1", "uid2"],
  "lastMessage": "string",
  "lastTimestamp": "timestamp"
}
```

### Subcollection: `chat_rooms/{roomId}/messages`
```json
{
  "senderId": "string",
  "receiverId": "string",
  "message": "string",
  "type": "text|image|video|file",
  "fileUrl": "string",
  "fileName": "string",
  "timestamp": "timestamp"
}
```

### Subcollection: `chat_rooms/{roomId}/typing`
```json
{
  "isTyping": "boolean",
  "timestamp": "timestamp"
}
```

## ⚙️ Presence System

**Prioritas:**
1. **Sedang melihat chat** — `inRoom: true` & `currentRoom == roomId`
2. **Online** — `online: true`
3. **Last seen** — `online: false` + `lastSeen` timestamp

**Deteksi lifecycle** menggunakan `WidgetsBindingObserver`:
- `resumed` → set online: true
- `paused/inactive/detached` → set online: false, keluar dari room

## 📦 Dependencies

```yaml
firebase_core: ^2.24.2
firebase_auth: ^4.16.0
cloud_firestore: ^4.14.0
firebase_storage: ^11.6.0
image_picker: ^1.0.7
file_picker: ^6.1.1
video_player: ^2.8.2
provider: ^6.1.1
cached_network_image: ^3.3.1
intl: ^0.19.0
timeago: ^3.6.1
```

## 📱 Platform

- **Android** (minSdk 21+)
- Flutter 3.x

## 🔮 Future Features

- [ ] Group chat
- [ ] Push notification (FCM)
- [ ] Dark mode
- [ ] Voice call
- [ ] AI auto reply
