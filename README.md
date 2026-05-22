# 💊 Smart Medicine Reminder App

A full-stack mobile application to help users manage medications, track health vitals, scan prescriptions, and get AI-powered medicine information.

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile Frontend** | Flutter (Dart) |
| **Backend API** | Node.js + Express |
| **Database** | MongoDB (Atlas for prod) |
| **AI Features** | Google Gemini API + OpenFDA API |
| **OCR** | Tesseract.js |
| **Push Notifications** | Web Push + Firebase |

## ✨ Features

- 📅 Medication schedule management with reminders
- 🔬 AI Prescription Scanner (OCR) — extracts medicine names only
- 💊 AI Medicine Chatbot — ask about any medicine (uses, side effects, dosage)
- 📊 Health vitals tracker (blood pressure, glucose, etc.)
- 👨‍👩‍👧 Family member profiles
- 📆 Appointment management
- 🆘 SOS emergency contact
- 🔄 Offline support with local SQLite sync

## 🚀 Deployment

### Backend — Deploy to Render.com (Free)

1. Go to [render.com](https://render.com) → **New Web Service**
2. Connect your GitHub repo: `TirthPanchal-06/Medicine-Reminder-App`
3. Set **Root Directory** to `backend`
4. Set **Build Command**: `npm install`
5. Set **Start Command**: `npm start`
6. Add Environment Variables in Render dashboard:
   - `MONGODB_URI` → Your MongoDB Atlas connection string
   - `JWT_SECRET` → A strong random secret (32+ chars)
   - `GEMINI_API_KEY` → Your Google AI Studio API key (optional)
   - `NODE_ENV` → `production`
7. Click **Deploy** — your backend will be live at `https://your-app.onrender.com`

### Flutter App — Update API URL

After deploying the backend:
1. Open `frontend/lib/services/api_service.dart`
2. Update `productionUrl` to your Render.com URL
3. Set `isProduction = true`
4. Build APK: `flutter build apk --release`

### MongoDB Atlas (Free Tier)

1. Go to [mongodb.com/atlas](https://www.mongodb.com/cloud/atlas)
2. Create a free cluster
3. Add a database user and whitelist `0.0.0.0/0` for Render access
4. Get your connection string and add to Render env vars

## 🔧 Local Development

### Backend
```bash
cd backend
cp .env.example .env    # Fill in your values
npm install
npm run dev
```

### Flutter Frontend
```bash
cd frontend
flutter pub get
flutter run
```

## 📱 Build APK

```bash
cd frontend
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## 📄 License
MIT
