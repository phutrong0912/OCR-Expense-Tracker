# Mini-Project 3: On-Device OCR Expense Tracker & Receipt Parser

[![Flutter CI & Build](https://github.com/user/ocr_expense_tracker/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/user/ocr_expense_tracker/actions)
[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart 3](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Google ML Kit](https://img.shields.io/badge/Google%20ML%20Kit-Offline%20OCR-4285F4?logo=google)](https://developers.google.com/ml-kit)
[![SQLite](https://img.shields.io/badge/Database-SQLite%20sqflite-003B57?logo=sqlite)](https://pub.dev/packages/sqflite)
[![Tests Passing](https://img.shields.io/badge/Tests-18%2F18%20Passed-10B981)](#testing--verification)

> An offline-first personal finance management application developed in Flutter with on-device AI. Powered by Google ML Kit Text Recognition, a custom heuristic regex parser for multi-format supermarket receipts, atomic SQLite persistence, and interactive animated Donut and Bar charts rendered strictly with `CustomPainter` (zero third-party chart libraries).

---

## 📦 Mandatory Mini-Project Submission Package (3 Deliverables)

### 1. Live Demo URL & Standalone Simulator
* **Interactive Live Web Demo**: Bundled in [`web/index.html`](web/index.html). Features full interactive simulation of the camera viewfinder with framing overlay, sub-100ms on-device OCR execution, the mandatory Review & Verification Screen, and pure Canvas CustomPainter animated charts.
* **Launch Locally in 1 Command**:
  ```bash
  python3 -m http.server 8080 --directory web
  ```
  Open `http://localhost:8080` in any web browser.
* **Cloudflare Pages / Vercel Deployment**: Drop the `web/` folder directly onto Cloudflare Pages or Vercel for instant static hosting.

### 2. GitHub Repository
* **Repository Architecture**: Clean layered architecture (`models/`, `database/`, `services/`, `screens/`, `widgets/charts/`).
* **Clean Commit History**: Semantic commits tracking each deliverable milestone.
* **CI/CD Pipeline**: GitHub Actions workflow at [`.github/workflows/flutter_ci.yml`](.github/workflows/flutter_ci.yml) for automated static analysis, test suite verification, and Android APK builds.

### 3. Short Technical Report (PDF)
* **Official 4-Page PDF Report**: Fully compiled and ready at:
  👉 [`OCR_Expense_Tracker_Report.pdf`](OCR_Expense_Tracker_Report.pdf)
* **Contents**:
  * Page 1: Executive Summary, Target Scenario & Official Feature Checklist Matrix.
  * Page 2: System Architecture Diagram, Multi-Pass Regex Heuristics Specification & Test Benchmarks.
  * Page 3: SQLite ER Diagram Schema, Relational Cascade & Pure CustomPainter Canvas Mathematics.
  * Page 4: Core User Journey, UI Screen Specs, Offline vs Cloud Benchmark & Submission Links.

---

## 🎯 Problem Scenario & Target Audience
University students and club treasurers frequently handle physical supermarket receipts, food stalls bills, and ride tickets. Manually entering expenses into spreadsheets is tedious and prone to clerical errors. 

**OCR Expense Tracker** solves this with:
1. **Sub-100ms offline text extraction** using Google ML Kit on-device neural models ($0.00 cloud API cost).
2. **Resilient regex heuristics** tailored for Vietnamese (`150.000 đ`, `150,000 VND`, `45k`) and international (`$12.50`) formats.
3. **Mandatory Review & Verification Screen** where users manually inspect bounding lines and correct noisy optical mistakes before committing records to SQLite.
4. **Pure Canvas Visualizations** (`CustomPainter`) delivering smooth 60fps animations and touch-to-explode interaction.



## 🧠 Regex Heuristic Parser Engine (`lib/services/regex_parser.dart`)

The OCR output from physical receipts is often optical noise. The parser uses multi-pass scoring heuristics:

### 1. Monetary Total Extraction
* **Priority Keywords**: Detects `TỔNG CỘNG`, `THÀNH TIỀN`, `TỔNG TIỀN`, `THANH TOÁN`, `GRAND TOTAL`, `AMOUNT DUE`, `TOTAL`.
* **Negative Exclusions**: Discards cash tendered (`Tiền khách đưa`, `Cash Tendered`), change returned (`Tiền thối lại`, `Change Due`), discounts (`Giảm giá`), VAT, phone numbers, and tax codes (`MST`).
* **Grouping Distinctions**:
  * 3 digits after separator (`\.\d{3}`): Treated as Vietnamese thousand separators (`94.000` -> `94000`).
  * 1-2 digits after separator (`\.\d{1,2}`): Treated as standard decimals (`10.53` -> `10.53`).
  * Shorthand support: Parses `k` suffix (`45k` -> `45000`).
* **Spatial Fallback**: If receipts are torn at the bottom, scans the lower 40% of the token stream for the largest valid monetary candidate.

### 2. Transaction Date Extraction
* Supports `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`, `YYYY-MM-DD`, and textual format `Ngày DD tháng MM năm YYYY`.
* Plausibility bounds verification: ensures month $\in [1, 12]$, day $\in [1, 31]$, and year $\in [2000, 2035]$.

### 3. Retail Merchant Dictionary & Auto-Categorization
* Pre-loaded retail dictionary of 50+ popular chains: *Highlands Coffee, Phúc Long, The Coffee House, Circle K, 7-Eleven, FamilyMart, WinMart, Co.opmart, Fahasa, CGV, Grab, Thế Giới Di Động, etc.*
* Boundary-isolated regex keyword matching prevents false substrings (e.g. `vé xem phim` correctly isolates to Entertainment rather than matching `vé xe` under Travel).




## 🗄️ Database Schema (SQLite)

```sql
-- Main Receipts Table
CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant TEXT NOT NULL,
  total_amount REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'VND',
  date TEXT NOT NULL,
  category_id TEXT NOT NULL,
  image_path TEXT,
  thumbnail_path TEXT,
  raw_ocr_text TEXT,
  notes TEXT,
  created_at TEXT NOT NULL
);

-- Itemized Receipt Lines (1-to-Many)
CREATE TABLE receipt_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  quantity REAL NOT NULL DEFAULT 1.0,
  unit_price REAL NOT NULL DEFAULT 0.0,
  total_price REAL NOT NULL,
  raw_line TEXT,
  FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
);

CREATE INDEX idx_receipts_date ON receipts (date);
CREATE INDEX idx_receipts_category ON receipts (category_id);
```


## 🚀 How to Run Locally

### Prerequisites
* Flutter SDK 3.10+ & Dart 3.0+
* Android Studio / Xcode (for device compilation)

### Steps
1. **Clone the repository**:
   ```bash
   git clone https://github.com/user/ocr_expense_tracker.git
   cd "ocr_expense_tracker"
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Run all tests**:
   ```bash
   dart run test/run_all_tests.dart
   ```

4. **Launch on Device / Emulator**:
   ```bash
   flutter run
   ```

5. **Build Android Release APK**:
   ```bash
   flutter build apk --release
   ```
   The generated APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License
This project is open-source under the MIT License. Developed for Mini-Project 3: OCR Expense Tracker & Receipt Parser.

