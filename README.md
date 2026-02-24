# MindSpace (CBT Application)

Welcome to **MindSpace**, a comprehensive Cognitive Behavioral Therapy (CBT) and Mental Health tracking application. This project is divided into two primary parts: a Flutter mobile application for the frontend and a Python FastAPI service for the backend.

## 📸 How the App Looks

<h3 align="center">Walkthrough & Onboarding</h3>
<p align="center">
  <img src="App%20Screenshots/walkthrough-1.png" width="18%" />
  <img src="App%20Screenshots/walkthrough-2.png" width="18%" />
  <img src="App%20Screenshots/walkthrough-3.png" width="18%" />
  <img src="App%20Screenshots/walkthrough-4.png" width="18%" />
  <img src="App%20Screenshots/walkthrough-5.png" width="18%" />
</p>

<h3 align="center">Authentication</h3>
<p align="center">
  <img src="App%20Screenshots/login.png" width="22%" />
  <img src="App%20Screenshots/signup.png" width="22%" />
</p>

<h3 align="center">Core Features & Therapy Flow</h3>
<p align="center">
  <img src="App%20Screenshots/home.png" width="22%" />
  <img src="App%20Screenshots/options.png" width="22%" />
  <img src="App%20Screenshots/weekly-activity-page.png" width="22%" />
  <img src="App%20Screenshots/share-reports-page.png" width="22%" />
</p>

<h3 align="center">Feature Showcases</h3>
<p align="center">
  <img src="App%20Screenshots/showcase-1%20.png" width="18%" />
  <img src="App%20Screenshots/showcase-2.png" width="18%" />
  <img src="App%20Screenshots/showcase-3.png" width="18%" />
  <img src="App%20Screenshots/showcase-4.png" width="18%" />
  <img src="App%20Screenshots/showcase-5.png" width="18%" />
</p>

---

## 🏗️ Project Structure

The repository contains the following main directories:

- **`cbt-frontend/`**: The mobile client built using Flutter and Dart.
- **`cbt-backend/`**: The intelligent backend service powered by FastAPI, Google GenAI (Gemini), and Groq.

---

## 📱 Frontend (`cbt-frontend`)

The mobile application designed to provide users with a clean, interactive interface.

### Tech Stack & Features
- **Framework**: Flutter (Dart)
- **State & Local Storage**: `shared_preferences`, `sqflite` (SQLite)
- **Backend-as-a-Service**: Firebase (Authentication & Cloud Firestore for securely storing user profiles, including names, emails, and mobile numbers).
- **Data Export capabilities**: Excel report synthesis via the FastAPI backend (`.xlsx`) and native file sharing (`share_plus`).
- **Other utilities**: Permission handling (`permission_handler`), file access, and HTTP requests (`http`).

### How to run the Frontend
1. Ensure you have Flutter installed (`flutter doctor`) and an emulator running or a physical device connected.
2. Navigate to the frontend directory:
   ```bash
   cd cbt-frontend
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. **Configure Firebase**:
   - Ensure you have a Firebase project set up.
   - For Android: Download `google-services.json` from your Firebase console and place it in `android/app/`.
   - For iOS: Download `GoogleService-Info.plist` and place it in the `ios/Runner/` directory (ensure it is linked via Xcode if needed).
5. Run the application:
   ```bash
   flutter run
   ```

---

## ⚙️ Backend (`cbt-backend`)

The backend component manages AI interactions, cognitive behavioral models (like the depression severity questionnaire and thought records), and reporting. 

### Tech Stack & Features
- **Framework**: FastAPI (served by `uvicorn`)
- **AI Integrations**: 
  - `google-genai`
  - `groq`
- **Excel Report Generation**: `openpyxl`
- **Core Functionality**:
  - **PHQ-9 Assessment**: A clinical conversation loop determining depression severity.
  - **Weekly Activity Journal**: Interactive chat-based tracking for users' weekly updates.
  - **Thought Records**: Tracks cognitive restructuring (identifying triggers, negative thoughts, feelings, and creating balanced thoughts).
  - **Exporting**: Excel file generation via memory streams (`StreamingResponse`).

### How to run the Backend
1. Ensure you have Python 3.8+ installed.
2. Navigate to the backend directory:
   ```bash
   cd cbt-backend
   ```
3. Set up a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. Ensure you have a `.env` file configured in the `cbt-backend` directory with valid API keys (e.g., Gemini, Groq credentials).
6. Run the server:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
7. Visit `http://127.0.0.0:8000/docs` or `http://localhost:8000/docs` to test endpoints via the Swagger UI.

---

## ✨ Key Capabilities

1. **Conversational Screening**: Leverages AI to conduct PHQ-9 depression screening conversationally rather than as an old-fashioned form.
2. **Cognitive Restructuring**: Implementation of traditional CBT elements (Thought Record sheets) to log triggers, emotional responses, negative automatic thoughts, and cognitive re-framing.
3. **Data Portability**: Users can export their logs and reports securely to Excel and natively share them directly from the app.
4. **Local & Cloud Syncing**: Integration with Firestore for cloud access alongside local `sqflite` cache.

---

## 🤝 Contributing

We welcome contributions to **MindSpace**! Whether you want to add a new feature, fix a bug, or improve documentation, here's how you can help:

1. **Fork the repository**: Click the "Fork" button at the top right of this page.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/your-username/CBT-4.0.git
   cd CBT-4.0
   ```
3. **Create a new branch**: 
   ```bash
   git checkout -b feature/your-amazing-feature
   ```
4. **Make your changes**: Implement your logic, add tests if applicable.
5. **Commit your changes**:
   ```bash
   git commit -m "Add some feature"
   ```
6. **Push to the branch**:
   ```bash
   git push origin feature/your-amazing-feature
   ```
7. **Open a Pull Request**: Navigate to the original repository and click "Compare & pull request".

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👨‍💻 Author

Built with ❤️ by **Naresh Kumar**
If you have any questions or suggestions, feel free to reach out at **nareshjangir6184@gmail.com** or open an issue!
