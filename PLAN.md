# SoloPoint - Offline POS System Plan

## 1. Project Overview
**Name:** SoloPoint  
**Type:** Point of Sale (POS) System  
**Target Industries:** Retail, Cafe, Restaurant  
**Platform:** Android (Primary), iOS/Windows (Supported via Flutter)  
**Core Philosophy:** 100% Offline, No Cloud (Privacy First), Local Data Ownership.

## 2. Technology Stack
*   **Framework:** Flutter (Dart)
*   **Local Database:** **Drift (SQLite)** or **Isar**
    *   *Recommendation:* **Drift** is chosen for its robust SQL support, relational data handling (essential for complex orders/reports), and compile-time safety.
*   **State Management:** **Flutter Riverpod**
    *   Modern, safe, and testable state management.
*   **Printer Integration:** `esc_pos_utils` / `blue_thermal_printer` (for Bluetooth/USB thermal printers).
*   **Icons:** Material Symbols.
*   **Architecture:** Feature-first modular architecture.

## 3. Key Features

### A. General (All Modes)
*   **Dashboard:** Quick view of daily sales, total orders.
*   **User Management:** Admin/Staff roles (Local PIN protection).
*   **Settings:** 
    *   Tax configurations (Inclusive/Exclusive).
    *   Currency formatting.
    *   Receipt customization (Logo, Header, Footer).
    *   Backup/Restore (Export database file to local storage/USB).
*   **Reporting:**
    *   Sales Summary (Day, Week, Month).
    *   Top Selling Items.
    *   Payment Method breakdown (Cash, Card, QR).
    *   Export reports to CSV/PDF.

### B. Retail Mode
*   **Inventory:** 
    *   Barcode Scanning support (Camera & External Scanner).
    *   Stock tracking (Simple quantity decrement).
    *   Alerts for low stock.
*   **Products:** 
    *   Variants (e.g., Size, Color) with different prices/SKUs.
*   **Customers:** 
    *   Local customer database (Phone, Name, History). 
    *   basic loyalty/points (optional).

### C. Cafe / Restaurant Mode
*   **Table Management:** 
    *   Floor plan view (Grid of tables).
    *   Status indicators (Available, Occupied, Bill Printed).
*   **Ordering:**
    *   Modifiers/Add-ons (e.g., "Extra Shot", "No Sugar", "Soy Milk").
    *   Notes per item.
*   **Bill Splitting:** Split by number of people or by items (Future phase).

## 4. Database Schema (Conceptual)

### 1. Catalog
*   **Categories:** `id`, `name`, `color`, `icon`.
*   **Products:** `id`, `categoryId`, `name`, `sku`, `barcode`, `price`, `cost`, `stockQuantity`, `trackStock` (bool), `isVariable` (bool).
*   **Modifiers:** `id`, `name` (e.g., "Toppings"), `isMultipleChoice`.
*   **ModifierItems:** `id`, `modifierId`, `name` (e.g., "Cheese"), `priceDelta`.

### 2. Operations
*   **Orders:** `id`, `orderNumber`, `timestamp`, `status` (Pending, Completed, Void), `subtotal`, `tax`, `discount`, `total`, `paymentMethod`, `tableId` (nullable), `customerId` (nullable).
*   **OrderItems:** `id`, `orderId`, `productId`, `variantName`, `quantity`, `unitPrice`, `notes`.
*   **OrderItemModifiers:** `id`, `orderItemId`, `modifierName`, `price`.

### 3. Business
*   **Transactions:** `id`, `orderId`, `amount`, `method` (Cash/Card), `timestamp`.
*   **Customers:** `id`, `name`, `phone`, `email`.
*   **Tables:** `id`, `name` (e.g., "T1"), `capacity`.

## 5. Development Roadmap

### Phase 1: Foundation (MVP)
1.  Setup Flutter project with Riverpod & GoRouter.
2.  Implement Drift Database connection.
3.  Create Basic CRUD for **Categories** and **Products**.
4.  Implement a simple **POS Grid View** (Add to cart).

### Phase 2: Core POS Transaction
1.  **Cart Logic**: Add/Remove items, quantity updates, calculate totals.
2.  **Checkout Screen**: Keypad for cash input, calculate change.
3.  **Order Storage**: Save completed orders to database.

### Phase 3: Advanced Features
1.  **Settings & Taxes**: Configure tax rates.
2.  **Receipt Printing**: Integration with thermal printers.
3.  **Reporting**: Basic daily sales chart.

### Phase 4: Vertical Specifics
1.  **Retail**: Barcode scanner integration.
2.  **Restaurant**: Table management screen & Modifiers UI.

## 6. Document Generation & Printing Strategy

Since you are building **SoloPOINT** with **Flutter**, you can leverage its robust package ecosystem to handle thermal printing and document generation natively across Android, iOS, and Desktop.

### 6.1 Recommended Flutter Tech Stack

* **For PDF & Printing:** `pdf` and `printing`. These work together to create PDF documents and send them to any printer (system or thermal) via a print preview.
* **For Thermal Printing (ESC/POS):** `flutter_pos_printer_platform`. This is the gold standard for sending raw commands to USB, Bluetooth, or Network thermal printers.
* **For CSV Export:** `csv`. A simple utility to turn your list of data into a downloadable string.

---

### 6.2 Implementation Plan for SoloPOINT

#### **Phase A: The Reporting UI**

Build a "Report Viewer" widget that fetches data. Use a `DataTable` or `SfDataGrid` (Syncfusion) for the screen view, but keep the data in a clean List of objects for the exporters.

#### **Phase B: PDF & CSV Generation**

* **PDF:** Create a "Document" object using the `pdf` package. Use `pw.Table.fromTextArray` to quickly turn your report data into a professional-looking PDF table.
* **CSV:** Map your report list to a `List<List<dynamic>>` and use the `ListToCsvConverter()`. Use `path_provider` to save it to the device's "Downloads" folder.

#### **Phase C: Thermal Printing Logic**

Thermal printers don't "render" graphics well; they like **ESC/POS commands**.

1. **Capability:** Create a "Receipt Generator" class.
2. **Formatting:** Use the `esc_pos_utils_plus` package to define text sizes (e.g., `PosTextSize.size2`) for report headers.
3. **The "Z-Report" Flow:** When a user clicks "Print to Thermal," the app should loop through the category totals and send them as lines of text rather than a full image to ensure high-speed printing.

---

### 6.3 Proposed Code Architecture

| Feature | Flutter Package | Best For... |
| --- | --- | --- |
| **PDF Export** | `pdf` / `printing` | Sending monthly sales reports to a manager's email. |
| **CSV Export** | `csv` / `share_plus` | Exporting inventory data for Excel analysis. |
| **Thermal Print** | `flutter_pos_printer_platform` | Quick end-of-day "X" or "Z" reports at the counter. |

### 6.4 Direct Thermal Printing Example

In Flutter, the logic for a thermal report usually looks like this:

```dart
final profile = await CapabilityProfile.load();
final generator = Generator(PaperSize.mm80, profile);
List<int> bytes = [];

bytes += generator.text('SoloPOINT SALES REPORT', styles: PosStyles(align: PosAlign.center, bold: true));
bytes += generator.hr();
bytes += generator.row([
  PosColumn(text: 'Category', width: 6),
  PosColumn(text: 'Total', width: 6, align: PosAlign.right),
]);
// Loop through your report data here...
```

---

## 7. Folder Structure
```
lib/
├── core/
│   ├── database/    # Drift setup
│   ├── theme/       # App styling
│   └── utils/       # Helpers (Currency, Date)
├── features/
│   ├── dashboard/
│   ├── inventory/   # Product/Category management
│   ├── pos/         # The main selling screen
│   ├── orders/      # Order history
│   ├── reports/
│   ├── settings/
│   └── tables/      # Restaurant table map
└── main.dart
```
