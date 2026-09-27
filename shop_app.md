# Clothing Store POS & Inventory Management System
## Product Requirements Document (PRD)

### 1. System Overview
A specialized Point of Sale (POS) and Inventory Management system designed specifically for a clothing retail store. The system focuses on cash-only transactions, variant management (sizes/colors), barcode generation and printing, precise return handling, and local data backup.

---

### 2. Core Modules & Features

#### 2.1. System Settings & Store Branding (إعدادات النظام وهواية المحل)
* **Store Profile:** Admin can upload a Store Logo and input Store Name, Slogan, Phone Number, and Address.
* **Dynamic Invoicing:** The saved store details (Logo, Name, Slogan, Contact) must automatically reflect on the header and footer of all printed receipts.

#### 2.2. Point of Sale (POS) & Checkout (نظام المبيعات)
* **Cash-Only Checkout:** The payment interface only supports Cash. It must include an input field for "Amount Received" and automatically calculate the "Change Due" for the customer.
* **Barcode Scanning:** Fast item adding to the cart via barcode scanner.
* **Thermal Receipt Printing:** Upon checkout confirmation, automatically generate and print a receipt containing:
  * Store Header (Logo, Name, Slogan, Details)
  * Invoice ID, Date, and Time
  * Purchased Items (Name, Size/Color, Qty, Unit Price, Total Price)
  * Grand Total, Amount Paid, and Change.

#### 2.3. Inventory & Product Management (إدارة المخزون والمنتجات)
* **Product CRUD:** Add, Read, Update, and Delete products.
* **Variant Management:** Crucial for clothing. A single product can have multiple variants (e.g., T-Shirt -> Colors: Red, Blue -> Sizes: S, M, L, XL). Stock is tracked per variant.
* **Product Editing:** Users can search for an existing product and fully edit its details (change product name, update selling price, manually adjust stock quantities for specific variants).
* **Low Stock Alerts:** Dashboard notifications when a variant's stock drops to a predefined minimum (e.g., 1 or 2 pieces).

#### 2.4. Advanced Barcode System (نظام الباركود)
* **Barcode Generation:** System automatically generates a unique barcode for each product variant if not provided by the manufacturer.
* **Custom Quantity Printing:** From the product edit page, users can click "Print Barcodes", enter a specific **number of copies**, and print them. 
* **Label Design:** The printed barcode label must include: The Barcode, Product Name (Short), Size/Color, Price, and Store Name.

#### 2.5. Returns & Restocking (المرتجعات)
* **Return Processing:** A dedicated screen to process returns via scanning the item's barcode or entering the invoice number.
* **Automated Sync:** Confirming a return triggers two automated actions:
  1. **Inventory:** The specific variant is restocked (quantity +1).
  2. **Financials:** The cash amount is deducted from the current shift's cash drawer total.

#### 2.6. Shift Management & Reports (الورديات والتقارير)
* **Shift Closing:** End-of-day feature to close the register. It displays the expected cash amount (based on sales minus returns) to be matched with the physical cash drawer.
* **Financial Reports:** Calculate Net Profit (Total Sales Revenue - Cost of Goods Sold).
* **Inventory Reports:** Identify best-selling items and slow-moving stock.

#### 2.7. Data Backup & Restore (النسخ الاحتياطي)
* **Manual Backup:** A button to export the entire database.
* **Custom Path Selection:** The system must open a file dialog allowing the user to choose *where* to save the backup file (e.g., USB drive, specific local folder).
* **Restore:** Ability to import a previously saved backup file to restore system state.

#### 2.8. User Roles & Permissions (الصلاحيات)
* **Admin (Owner):** Full access (Settings, Edit Products, Backup/Restore, Profit Reports).
* **Cashier:** Restricted access. Only allowed to use the POS screen, process returns, and print invoices. Cannot edit system settings or view profit margins.

---

### 3. Suggested Database Entities (For AI Reference)
* **User:** id, name, role (admin/cashier), password.
* **StoreSettings:** id, name, logo_url, slogan, phone, address.
* **Product:** id, name, description, category.
* **ProductVariant:** id, product_id, sku/barcode, size, color, cost_price, selling_price, stock_quantity.
* **Order (Invoice):** id, total_amount, amount_paid, change_due, status (completed/returned), created_at, cashier_id.
* **OrderItem:** id, order_id, variant_id, quantity, unit_price, total_price, returned_quantity.
* **Shift:** id, cashier_id, start_time, end_time, expected_cash, actual_cash, status (open/closed).

### 4. Technical Notes for Development
* The UI should be responsive but optimized for desktop/tablet landscape orientation (standard POS hardware).
* The print functionality should target standard Thermal Receipt Printers (typically 80mm or 58mm width).
* Implement state management to ensure that inventory edits and returns immediately reflect on the POS screen without needing a page refresh.
```eof