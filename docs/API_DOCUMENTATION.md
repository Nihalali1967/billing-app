# Star Chips — Mobile API Documentation

**Base URL:** `http://your-domain.com/api`  
**Auth:** Laravel Sanctum — Bearer Token  
**Content-Type:** `application/json`  
**All responses include:** `"success": true|false`

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Dashboard](#2-dashboard)
3. [Products](#3-products)
4. [Customers](#4-customers)
5. [Billing Flow (Preview → Finalize)](#5-billing-flow)
6. [Bill History & Management](#6-bill-history--management)
7. [User Management (Admin)](#7-user-management-admin-only)
8. [Error Responses](#8-error-responses)
9. [Mobile Billing Flow Diagram](#9-mobile-billing-flow-diagram)

---

## 1. Authentication

### 1.1 Login
Login with username/mobile number and password.

**POST** `/api/auth/login`  
_No authentication required_

**Request Body:**
```json
{
  "login": "admin",
  "password": "password123"
}
```
> `login` accepts either a **username** (string) or **mobile number** (numeric string).

**Success Response — 200:**
```json
{
  "success": true,
  "message": "Login successful.",
  "token": "1|aBcDeFgHiJkLmNoPqRsTuVwXyZ...",
  "user": {
    "id": 1,
    "name": "Admin User",
    "username": "admin",
    "mobile": "9876543210",
    "role": "admin",
    "is_active": true
  }
}
```
> Store `token` securely. Send it as `Authorization: Bearer <token>` on all subsequent requests.

**Error — 401:**
```json
{ "success": false, "message": "Invalid credentials. Please try again." }
```

**Error — 403 (Deactivated account):**
```json
{ "success": false, "message": "Your account has been deactivated. Contact admin." }
```

---

### 1.2 Logout
Revokes the current access token.

**POST** `/api/auth/logout`  
_Requires: Bearer Token_

**Success Response — 200:**
```json
{ "success": true, "message": "Logged out successfully." }
```

---

### 1.3 Get Authenticated User
**GET** `/api/auth/me`  
_Requires: Bearer Token_

**Success Response — 200:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "name": "Admin User",
    "username": "admin",
    "mobile": "9876543210",
    "role": "admin",
    "is_active": true
  }
}
```

---

## 2. Dashboard

### 2.1 Dashboard Stats
Returns today's summary, 7-day chart data, recent bills, and top customers.

**GET** `/api/dashboard`  
_Requires: Bearer Token_

**Success Response — 200:**
```json
{
  "success": true,
  "data": {
    "today": {
      "sales": 15420.50,
      "collected": 12000.00,
      "credit": 3420.50,
      "bill_count": 8
    },
    "totals": {
      "customers": 142,
      "products": 35,
      "credit_balance": 25800.00,
      "extra_amount": 1200.00
    },
    "last_7_days": [
      { "date": "2024-03-05", "label": "Mar 05", "day": "Tue", "sales": 12500.00 },
      { "date": "2024-03-06", "label": "Mar 06", "day": "Wed", "sales": 18300.00 }
    ],
    "recent_bills": [
      {
        "id": 101,
        "bill_number": "A101",
        "customer_name": "Ravi Kumar",
        "customer_shop": "Ravi Stores",
        "total": 2450.00,
        "collected_amount": 2000.00,
        "credit_amount": 450.00,
        "billed_by": "Admin User",
        "date": "11 Mar 2024, 10:30 AM",
        "created_at": "2024-03-11T05:00:00.000Z"
      }
    ],
    "top_customers": [
      {
        "id": 5,
        "name": "Suresh Babu",
        "shop_name": "Suresh Traders",
        "total_spent": 45000.00,
        "credit_balance": 1200.00
      }
    ]
  }
}
```

---

## 3. Products

### 3.1 List Products
**GET** `/api/products`  
_Requires: Bearer Token_

**Query Parameters:**

| Param        | Type   | Description                          |
|-------------|--------|--------------------------------------|
| `search`    | string | Filter by name or description        |
| `active_only`| bool  | Pass `1` to return active only       |
| `per_page`  | int    | Items per page (default: 15)         |
| `page`      | int    | Page number                          |

**Success Response — 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Classic Salted Chips",
      "price": 120.00,
      "unit_type": "box",
      "description": "500g box of classic salted chips",
      "is_active": true,
      "image_url": "http://domain.com/storage/products/chips.jpg",
      "created_at": "2024-01-01T10:00:00.000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 3,
    "per_page": 15,
    "total": 35
  }
}
```

---

### 3.2 Search Products (for billing autocomplete)
**GET** `/api/products/search?q=chips`  
_Requires: Bearer Token_

Returns active products matching the query (max 20).

```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "Classic Salted Chips", "price": 120.00, "unit_type": "box", "image_url": null, "is_active": true }
  ]
}
```

---

### 3.3 Get Single Product
**GET** `/api/products/{id}`

---

### 3.4 Create Product
**POST** `/api/products`  
_Requires: Bearer Token_  
Content-Type: `multipart/form-data` (if uploading image)

**Request Body:**

| Field         | Type    | Required | Description                  |
|--------------|---------|----------|------------------------------|
| `name`       | string  | Yes      | Product name                 |
| `price`      | numeric | Yes      | Unit price                   |
| `unit_type`  | string  | Yes      | e.g. `box`, `kg`, `piece`    |
| `description`| string  | No       | Optional description         |
| `image`      | file    | No       | JPEG/PNG/WEBP, max 2MB       |

**Success Response — 201:**
```json
{ "success": true, "message": "Product created successfully.", "data": { ...product } }
```

---

### 3.5 Update Product
**PUT** `/api/products/{id}`

Same fields as create, plus `is_active` (boolean).

---

### 3.6 Delete Product
**DELETE** `/api/products/{id}`

```json
{ "success": true, "message": "Product deleted successfully." }
```

---

## 4. Customers

### 4.1 List Customers
**GET** `/api/customers`  
_Requires: Bearer Token_

**Query Parameters:** `search`, `per_page`, `page`

**Success Response — 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Ravi Kumar",
      "shop_name": "Ravi Stores",
      "mobile": "9876543210",
      "mobile_secondary": null,
      "location": "Chennai",
      "credit_balance": 1500.00,
      "extra_amount": 0.00,
      "display_name": "Ravi Kumar (Ravi Stores)",
      "created_at": "2024-01-10T00:00:00.000Z"
    }
  ],
  "meta": { "current_page": 1, "last_page": 5, "per_page": 15, "total": 142 }
}
```

---

### 4.2 Search Customers (for billing autocomplete)
**GET** `/api/customers/search?q=ravi`  
Returns top 20 matches by name, shop name, or mobile.

---

### 4.3 Get Customer with Bill History
**GET** `/api/customers/{id}`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Ravi Kumar",
    "shop_name": "Ravi Stores",
    "mobile": "9876543210",
    "credit_balance": 1500.00,
    "extra_amount": 0.00,
    "total_bills": 12,
    "total_spent": 45000.00,
    "recent_bills": [ { "id": 101, "bill_number": "A101", "total": 2450.00, ... } ]
  }
}
```

---

### 4.4 Get Customer Credit Balance
**GET** `/api/customers/{id}/credit`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Ravi Kumar",
    "shop_name": "Ravi Stores",
    "credit_balance": 1500.00,
    "extra_amount": 0.00
  }
}
```

---

### 4.5 Create Customer
**POST** `/api/customers`

| Field              | Required |
|--------------------|----------|
| `name`             | Yes      |
| `mobile`           | Yes      |
| `shop_name`        | No       |
| `mobile_secondary` | No       |
| `location`         | No       |
| `credit_balance`   | No       |
| `extra_amount`     | No       |

---

### 4.6 Update Customer
**PUT** `/api/customers/{id}`

---

### 4.7 Delete Customer
**DELETE** `/api/customers/{id}`

---

## 5. Billing Flow

The mobile billing flow is **two-step**, mirroring the web preview → confirm pattern.  
Instead of PHP sessions, a **`preview_token`** (UUID) is used to identify the cached preview server-side.

```
POST /api/billing/preview
        ↓
   Returns: preview_token + full computed preview data
        ↓
   App shows Preview Page (no bill created yet)
        ↓
POST /api/billing/finalize  { preview_token }
        ↓
   Bill saved → Returns saved bill data
        ↓
   App navigates to Bill Details Page
```

---

### 5.1 Step 1 — Generate Preview
Validates bill data, computes all financial totals, stores in cache (30 min TTL), and returns the preview. **Does NOT save a bill.**

**POST** `/api/billing/preview`  
_Requires: Bearer Token_

**Request Body:**
```json
{
  "customer_id": 1,
  "items": [
    {
      "product_id": 3,
      "quantity": 5,
      "unit_price": 120.00,
      "is_custom_price": false,
      "custom_price": null
    },
    {
      "product_id": 7,
      "quantity": 2,
      "unit_price": 80.00,
      "is_custom_price": true,
      "custom_price": 70.00
    }
  ],
  "discount": 50.00,
  "collected_amount": 500.00,
  "notes": "Delivered to shop"
}
```

**Field Reference:**

| Field                       | Type    | Required | Description                                              |
|-----------------------------|---------|----------|----------------------------------------------------------|
| `customer_id`               | int     | Yes      | Existing customer ID                                     |
| `items`                     | array   | Yes      | Min 1 item                                               |
| `items[].product_id`        | int     | Yes      | Existing active product ID                               |
| `items[].quantity`          | numeric | Yes      | Can be decimal (e.g. 2.5)                                |
| `items[].unit_price`        | numeric | Yes      | The product's standard price                             |
| `items[].is_custom_price`   | bool    | No       | Set `true` to override price                             |
| `items[].custom_price`      | numeric | No       | Required when `is_custom_price = true`                   |
| `discount`                  | numeric | No       | Flat discount on total                                   |
| `collected_amount`          | numeric | Yes      | Cash collected from customer                             |
| `notes`                     | string  | No       | Optional notes (max 1000 chars)                          |

**Success Response — 200:**
```json
{
  "success": true,
  "message": "Bill preview generated.",
  "preview_token": "550e8400-e29b-41d4-a716-446655440000",
  "expires_in": 1800,
  "data": {
    "customer_id": 1,
    "customer": {
      "id": 1,
      "name": "Ravi Kumar",
      "shop_name": "Ravi Stores",
      "mobile": "9876543210",
      "location": "Chennai"
    },
    "items": [
      {
        "product_id": 3,
        "product_name": "Classic Salted Chips",
        "quantity": 5,
        "unit_price": 120.00,
        "custom_price": null,
        "is_custom_price": false,
        "total": 600.00,
        "unit_type": "box"
      },
      {
        "product_id": 7,
        "product_name": "Masala Chips",
        "quantity": 2,
        "unit_price": 80.00,
        "custom_price": 70.00,
        "is_custom_price": true,
        "total": 140.00,
        "unit_type": "box"
      }
    ],
    "subtotal": 740.00,
    "discount": 50.00,
    "total": 690.00,
    "collected_amount": 500.00,
    "credit_amount": 190.00,
    "previous_credit": 1500.00,
    "previous_extra": 0.00,
    "notes": "Delivered to shop",
    "final_credit_balance": 1690.00,
    "final_extra_amount": 0.00
  }
}
```

**Financial Logic:**
```
subtotal          = sum of (effective_price × quantity)
total             = subtotal − discount
credit_amount     = max(0, total − collected_amount)
effective_payment = collected_amount + previous_extra
total_owed        = total + previous_credit
remaining         = total_owed − effective_payment

final_credit_balance = remaining > 0 ? remaining : 0
final_extra_amount   = remaining < 0 ? abs(remaining) : 0
```

---

### 5.2 Re-fetch Preview (optional)
Use this if the app needs to reload the preview screen from cache.

**GET** `/api/billing/preview/{token}`  
_Requires: Bearer Token_

**Success Response — 200:**
```json
{ "success": true, "data": { ...same preview data object... } }
```

**Error — 404:**
```json
{ "success": false, "message": "Preview expired or not found. Please create the bill again." }
```

---

### 5.3 Preview WhatsApp Data
Get the formatted WhatsApp message for the preview (before bill is saved).

**POST** `/api/billing/preview/whatsapp`  
_Requires: Bearer Token_

**Request Body:**
```json
{ "preview_token": "550e8400-e29b-41d4-a716-446655440000" }
```

**Success Response — 200:**
```json
{
  "success": true,
  "data": {
    "message": " *BILL PREVIEW*\n 11/03/2024\n\n Ravi Kumar\n Ravi Stores\n 9876543210\n\n *ITEMS:*\n...",
    "whatsapp_url": "https://wa.me/?text=...",
    "customer_mobile": "9876543210",
    "customer_whatsapp_url": "https://wa.me/919876543210?text=..."
  }
}
```

---

### 5.4 Step 2 — Finalize (Create Bill)
Consumes the `preview_token`, creates the bill and items in the database, updates customer credit/extra balance, and returns the saved bill.

**POST** `/api/billing/finalize`  
_Requires: Bearer Token_

**Request Body:**
```json
{ "preview_token": "550e8400-e29b-41d4-a716-446655440000" }
```

**Success Response — 201:**
```json
{
  "success": true,
  "message": "Bill created successfully!",
  "data": {
    "id": 101,
    "bill_number": "A101",
    "status": "completed",
    "subtotal": 740.00,
    "discount": 50.00,
    "total": 690.00,
    "collected_amount": 500.00,
    "credit_amount": 190.00,
    "previous_credit": 1500.00,
    "notes": "Delivered to shop",
    "customer": {
      "id": 1,
      "name": "Ravi Kumar",
      "shop_name": "Ravi Stores",
      "mobile": "9876543210",
      "location": "Chennai",
      "credit_balance": 1690.00,
      "extra_amount": 0.00
    },
    "billed_by": { "id": 1, "name": "Admin User" },
    "items": [
      {
        "id": 201,
        "product_id": 3,
        "product_name": "Classic Salted Chips",
        "unit_type": "box",
        "quantity": 5.0,
        "unit_price": 120.00,
        "custom_price": null,
        "is_custom_price": false,
        "effective_price": 120.00,
        "total": 600.00
      }
    ],
    "date": "11 Mar 2024, 10:30 AM",
    "created_at": "2024-03-11T05:00:00.000Z",
    "updated_at": "2024-03-11T05:00:00.000Z"
  }
}
```

---

### 5.5 Get WhatsApp Data for Saved Bill (via Billing Controller)
**GET** `/api/billing/{bill_id}/whatsapp`  
Same response format as [6.4 Bill WhatsApp Data](#64-bill-whatsapp-data).

---

## 6. Bill History & Management

### 6.1 List Bills
**GET** `/api/bills`  
_Requires: Bearer Token_

**Query Parameters:**

| Param         | Type   | Description                      |
|--------------|--------|----------------------------------|
| `search`     | string | Filter by bill number             |
| `customer_id`| int    | Filter by customer                |
| `user_id`    | int    | Filter by billed-by user          |
| `date_from`  | date   | Format: `YYYY-MM-DD`             |
| `date_to`    | date   | Format: `YYYY-MM-DD`             |
| `per_page`   | int    | Default: 20                       |
| `page`       | int    | Page number                       |

**Success Response — 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 101,
      "bill_number": "A101",
      "customer_name": "Ravi Kumar",
      "customer_shop": "Ravi Stores",
      "customer_mobile": "9876543210",
      "total": 690.00,
      "collected_amount": 500.00,
      "credit_amount": 190.00,
      "discount": 50.00,
      "status": "completed",
      "billed_by": "Admin User",
      "date": "11 Mar 2024, 10:30 AM",
      "created_at": "2024-03-11T05:00:00.000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 20,
    "total": 95,
    "summary": {
      "total_amount": 145000.00,
      "total_collected": 130000.00,
      "total_credit": 15000.00
    }
  }
}
```

---

### 6.2 Get Bill Detail
**GET** `/api/bills/{id}`

Returns full bill with items, customer info, and biller. Same structure as the finalize response above.

---

### 6.3 Get Bill Print Data
Returns the same complete bill detail, used by the mobile app to render its own A4 or thermal print/PDF layout.

**GET** `/api/bills/{id}/print`

---

### 6.4 Bill WhatsApp Data
Returns the pre-built WhatsApp message string and direct URLs.

**GET** `/api/bills/{id}/whatsapp`

**Success Response — 200:**
```json
{
  "success": true,
  "data": {
    "message": " *BILL*\n INVOICE #A101\n 11/03/24\n\n Ravi Kumar\n Ravi Stores\n 9876543210\n\n *ITEMS*\n1. Classic Salted Chips - box - Qty: 5 x ₹120.00 = ₹600.00\n\n *PAYMENT*\nSubtotal: ₹740.00\nDiscount: -₹50.00\n*Total:* ₹690.00\nPaid: ₹500.00\nCredit Due: ₹190.00\n",
    "whatsapp_url": "https://wa.me/?text=...",
    "customer_mobile": "9876543210",
    "customer_whatsapp_url": "https://wa.me/919876543210?text=..."
  }
}
```

> **Mobile Integration:**  
> - Open `whatsapp_url` to open WhatsApp with the message pre-filled (no specific contact).  
> - Open `customer_whatsapp_url` to send directly to the customer's WhatsApp.  
> - Use the `message` string with the native share sheet (`Share.share()` in React Native / Flutter).

---

### 6.5 Update Bill
**PUT** `/api/bills/{id}`

| Field              | Required |
|--------------------|----------|
| `customer_id`      | Yes      |
| `discount`         | No       |
| `collected_amount` | No       |
| `notes`            | No       |

---

### 6.6 Delete Bill
**DELETE** `/api/bills/{id}`

Restores customer credit balance before deletion.

---

## 7. User Management (Admin Only)

All endpoints in this section require `role = admin`.

### 7.1 List Users
**GET** `/api/users`  
Query params: `search`, `per_page`, `page`

```json
{
  "success": true,
  "data": [
    {
      "id": 2,
      "name": "Sales User",
      "username": "sales1",
      "mobile": "9123456789",
      "role": "user",
      "is_active": true,
      "created_at": "2024-01-01T00:00:00.000Z"
    }
  ],
  "meta": { "current_page": 1, "last_page": 1, "per_page": 15, "total": 5 }
}
```

---

### 7.2 Create User
**POST** `/api/users`

| Field               | Required | Notes                     |
|--------------------|----------|---------------------------|
| `name`             | Yes      |                           |
| `username`         | Yes      | Must be unique            |
| `mobile`           | Yes      | Must be unique            |
| `password`         | Yes      | Min 6 chars               |
| `password_confirmation` | Yes |                          |
| `role`             | Yes      | `admin` or `user`         |

---

### 7.3 Update User
**PUT** `/api/users/{id}`

Same as create, plus `is_active` (boolean). Password fields are optional.

---

### 7.4 Delete User
**DELETE** `/api/users/{id}`

Cannot delete your own account (returns 403).

---

## 8. Error Responses

### Validation Error — 422
```json
{
  "message": "The customer_id field is required.",
  "errors": {
    "customer_id": ["The customer_id field is required."],
    "collected_amount": ["The collected amount field is required."]
  }
}
```

### Unauthorized — 401
```json
{ "message": "Unauthenticated." }
```

### Forbidden — 403
```json
{ "message": "Unauthorized. Admin access required." }
```

### Not Found — 404
```json
{ "message": "No query results for model [App\\Models\\Bill] 999" }
```

### Server Error — 500
```json
{ "success": false, "message": "Error creating bill: ..." }
```

---

## 9. Mobile Billing Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    MOBILE BILLING FLOW                    │
└─────────────────────────────────────────────────────────┘

 [1] BILLING FORM SCREEN
     ├── Search & select customer  →  GET /api/customers/search?q=
     │        └── Auto-fill credit info  →  GET /api/customers/{id}/credit
     ├── Add items (search products)  →  GET /api/products/search?q=
     │        └── Optionally set custom price per item
     ├── Enter discount, collected_amount, notes
     └── Tap "Preview"  →  POST /api/billing/preview
                                 ↓
                           Returns preview_token
                           + computed preview data
                                 ↓
 [2] BILL PREVIEW SCREEN  (bill NOT saved yet)
     ├── Display items, totals, credit summary
     ├── [Back & Edit]  →  navigate back (token still cached)
     ├── [Thermal Print]  →  render mobile thermal layout from preview data
     ├── [A4 Print / PDF]  →  render mobile A4 layout from preview data
     ├── [WhatsApp Share]  →  POST /api/billing/preview/whatsapp
     │                              → open whatsapp_url or customer_whatsapp_url
     └── [Create Bill]  →  POST /api/billing/finalize { preview_token }
                                 ↓
                           Bill saved → returns full bill object
                                 ↓
 [3] BILL DETAILS SCREEN  (bill IS saved)
     ├── Display bill #, customer, items, payment summary
     ├── [Thermal Print]  →  GET /api/bills/{id}/print → render thermal layout
     ├── [A4 / PDF Print]  →  GET /api/bills/{id}/print → render A4 layout
     ├── [WhatsApp Share]  →  GET /api/bills/{id}/whatsapp
     │                              → open whatsapp_url / customer_whatsapp_url
     └── [App Share]  →  use native Share API with the `message` text
```

---

## 10. HTTP Headers Reference

```
POST /api/auth/login
Content-Type: application/json

# All other requests:
Authorization: Bearer 1|aBcDeFgHiJkLmNoPqRsTuVwXyZ
Content-Type: application/json
Accept: application/json
```

> **Important:** Always include `Accept: application/json` so Laravel returns JSON error responses instead of HTML redirects.
