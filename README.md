# 🌤️ Atmosphere - Personal Weather Intelligence

**Developer:** Mohd Shaff Had Khan

**Project:** Technical Assessment #1 & #2 (Full Stack) - PM Accelerator

🟢 **Live Link:**  [Atmosphere_App](https://shaffhadk.github.io/weather_app_atmosphere/)

_**Note:** After clicking the link wait for a minute as the backend needs time to spool up._

## 📖 Project Overview

**Atmosphere** is a complete, full-stack weather application designed to provide users with real-time weather intelligence, interactive geographical maps, localized media, and historical data tracking.

This project successfully fulfills all requirements for both **Tech Assessment #1 and #2**, serving as a comprehensive Full Stack solution. It features a highly robust **FastAPI (Python)** backend connected to a **MySQL** database for complete CRUD functionality, paired with a premium **Flutter** frontend utilizing responsive Glassmorphic design with a sleek and modern look.

### Key Features Implemented:

* **Complete CRUD Operations (Backend & Frontend):** Users can search for a city, validate date ranges, and save the resulting forecast data to a MySQL database. Users can also Read, Update (edit the saved location/dates), and Delete their historical records seamlessly via the UI.
* **Individual CSV Data Export:** Users can download their historical weather data directly to their device. The backend securely flattens the JSON arrays and streams a cleanly formatted CSV file, while the frontend handles local blob downloads.
* **Dynamic API Integration:** Integrates with Open-Meteo for real-time, 24-hour, and historical 5-day forecasts, 24-hour forecasts, alongside dynamic URL generation for YouTube localized media based on the user's location.
* **Interactive Data Visualization:** A custom-built Canvas Painter in Flutter dynamically renders historical temperatures into a beautiful, smoothed line graph without relying on heavy external charting libraries.

---

## 🚀 How to Run the Application

This project is split into two distinct environments. Please ensure you have Python 3.9+ and the Flutter SDK installed on your machine.

### Part 1: Starting the Backend (FastAPI + MySQL)

**1. Database Setup:** Ensure you have MySQL (e.g., MySQL Workbench) running locally. Create a new database named `weather_db`:

```sql
CREATE DATABASE weather_db;
```
_(Note: If your local MySQL credentials differ from user ```root``` and password ```password123```, please update the ```SQLALCHEMY_DATABASE_URL``` string at the top of ```backend/main.py```)_

**2. Install Dependencies** Navigate to the backend directory and install the required Python packages:
```bash
cd backend
pip install -r requirements.txt
```
** 3. Run the Server** Launch the FastAPI application using Uvicorn. SQLAlchemy will automatically connect to your MySQL instance and generate the ```weather_records``` table upon startup.

```bash
uvicorn main:app --reload --port 8080
```

_The backend will now be actively listening on ```http://localhost:8080```._

### Part 2: Starting the Frontend (Flutter Web)

**1. Install Dependencies** Open a new terminal window, navigate to the frontend directory, and fetch the required Dart packages:

```bash
cd frontend
flutter pub get
```

**2. Launch the Application** Because this application uses web-specific data URI generation for file exporting, please run the application using Chrome or Edge:

```bash
flutter run -d chrome
```
_Note: Ensure your FastAPI backend server is actively running before attempting to search or save records in the Flutter UI._
