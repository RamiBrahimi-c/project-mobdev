
***

# SecureStream - Biometric Audio streaming System
**Mobile Development Project | USTHB - ING 3 SEC**

SecureStream is a high-security audio streaming application built with Flutter and Firebase. It implements a "Security-First" architecture, gating sensitive cloud data behind native hardware biometric authentication.

![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![Firebase](https://img.shields.io/badge/Backend-Firebase-orange)

## 🔐 Security Architecture

The application implements a multi-layer security protocol:

1.  **Native Biometric Gateway:** The `MainActivity` is intercepted at launch. The system requires a valid hardware fingerprint signature before initializing the Firebase Auth stack.
2.  **Identity Management:** Integrated Firebase Authentication with custom business logic to enforce a 13-year-old minimum age requirement via dynamic date calculation.
3.  **Biometric-Data Coupling (Secure Delete):** To fulfill the "High-Security Deletion" requirement, the application triggers a secondary biometric challenge before executing a `DELETE` request to the Firestore Favorites sub-collection.
4.  **Firestore Production Rules:** Implemented granular security rules using UID-matching to ensure zero-leakage between user environments.

## 📊 Data Visualization & State
*   **Dynamic Dashboard:** Real-time data visualization using `fl_chart`, mapping user activity into a daily histogram.
*   **Goal Persistence:** Monthly listening goals are managed via `SharedPreferences` for local persistence and low-latency UI updates.
*   **State Synchronization:** Utilizes a Global `AudioManager` singleton to maintain UI/Hardware synchronization, allowing a persistent "Mini-Player" to remain active on the dashboard while the main audio engine runs in the background.

## 🎵 Audio Engine
*   **Foreground Service:** Implemented Android Foreground Service permissions to prevent OS thread suspension during background playback.
*   **Dynamic API Integration:** REST API integration with `api.quran.com` and `mp3quran.net`.
*   **Category-Based Navigation:** Users can navigate by **Content (Surahs)** or **Authors (Reciters)**. Selecting a reciter dynamically swaps the remote audio server endpoint.
*   **Full Control Suite:** Real-time seek bar (clamped for boundary safety), play/pause, stop, and repeat modes.

## 🛠 Tech Stack
*   **Frontend:** Flutter (Dart)
*   **Backend:** Firebase (Auth, Firestore)
*   **Hardware API:** Android Biometric API (local_auth)
*   **Audio Engine:** Audioplayers (Low-latency stream)
*   **Design:** Neutral Night Mode (Deep Slate Palette)

## 🚀 Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/securestream.git
    ```
2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Firebase Configuration:**
    *   Place your `google-services.json` in `android/app/`.
    *   Ensure Firestore is enabled in **Production Mode** and rules are published.
4.  **Run Application:**
    ```bash
    flutter run
    ```

## 📝 Project Requirements Checklist (PDF)
- [x] Biometric authentication on launch.
- [x] Success sound feedback.
- [x] Firebase Signup/Login/Reset.
- [x] Age validation (>= 13 years).
- [x] Histogram of daily listening minutes.
- [x] Monthly goal dropdown (default 20h) with local storage.
- [x] Background audio playback.
- [x] Dynamic playlist via external API.
- [x] Repeat functionality.
- [x] Fingerprint required to delete favorites.

***

### 💡 Why "SecureStream"?
The name reflects the dual nature of the project: **Secure** (Biometric gating and verified deletion) and **Stream** (Dynamic API audio delivery). 
