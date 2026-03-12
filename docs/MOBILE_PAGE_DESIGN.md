# Star Chips — Mobile App Page Design Documentation

This document describes every screen in the Star Chips mobile app, its layout, components,
data sources, user actions, and navigation flow — mirroring the existing web application.

---

## Table of Contents

1. [App Architecture Overview](#1-app-architecture-overview)
2. [Authentication Flow](#2-authentication-flow)
3. [Dashboard Screen](#3-dashboard-screen)
4. [Products Module](#4-products-module)
5. [Customers Module](#5-customers-module)
6. [Billing Module (New Bill Flow)](#6-billing-module-new-bill-flow)
   - 6.1 [Billing Form Screen](#61-billing-form-screen)
   - 6.2 [Bill Preview Screen](#62-bill-preview-screen)
   - 6.3 [Bill Confirmed Screen (Details)](#63-bill-confirmed-screen--bill-details)
7. [Bill History Module](#7-bill-history-module)
8. [User Management Module (Admin)](#8-user-management-module-admin-only)
9. [Shared Components](#9-shared-components)
10. [Navigation Structure](#10-navigation-structure)
11. [Color & Typography System](#11-color--typography-system)
12. [Print & Share Flows](#12-print--share-flows)

---

## 1. App Architecture Overview

```
App
├── Auth Stack
│   └── LoginScreen
└── Main Stack (authenticated)
    ├── Bottom Tab Navigator
    │   ├── Dashboard Tab
    │   ├── New Bill Tab        ← primary action
    │   ├── Bills Tab
    │   └── More Tab (Customers, Products, Users, Logout)
    └── Modal / Full-Screen Stack
        ├── BillPreviewScreen
        ├── BillDetailScreen
        ├── CustomerDetailScreen
        ├── ProductFormScreen
        ├── CustomerFormScreen
        └── UserFormScreen
```

**State Management:** Each screen loads data via the API. Auth token is stored in secure storage.  
**Offline:** Not supported — all actions require connectivity.  
**Role-based UI:** Admin-only screens (Users, delete actions) are hidden for `role = user`.

---

## 2. Authentication Flow

### 2.1 Login Screen

**Route/Screen:** `LoginScreen`  
**API:** `POST /api/auth/login`

#### Layout
```
┌─────────────────────────────────┐
│         [App Logo]              │
│       Star Chips                │
│   Billing Management            │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Username or Mobile       │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  Password          [👁]   │  │
│  └───────────────────────────┘  │
│                                 │
│  [ LOGIN ]  ← primary button    │
│                                 │
│  Error message (if any)         │
└─────────────────────────────────┘
```

#### Components
- **Logo** — centered, ~80px tall
- **Title** — "Star Chips", subtitle "Billing Management"
- **Username/Mobile field** — text input, keyboard: default
- **Password field** — secure text input with show/hide toggle
- **Login button** — full-width, primary color, shows spinner on submit
- **Error text** — red, below button

#### Actions
| Action | Behavior |
|--------|----------|
| Tap Login | POST `/api/auth/login`, store token + user on success |
| Login success | Navigate to Dashboard (replace stack) |
| Login fail | Show error message from API |

#### Validations
- Both fields required before submitting

---

## 3. Dashboard Screen

**Route/Screen:** `DashboardScreen`  
**API:** `GET /api/dashboard`  
**Tab:** Dashboard

#### Layout
```
┌─────────────────────────────────┐
│ Star Chips           [Refresh]  │
│ Welcome, {name} · {role}        │
├─────────────────────────────────┤
│  Today's Summary                │
│  ┌──────────┐ ┌──────────┐      │
│  │  ₹15,420 │ │  ₹12,000 │      │
│  │  Sales   │ │ Collected│      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │  ₹3,420  │ │    8     │      │
│  │  Credit  │ │  Bills   │      │
│  └──────────┘ └──────────┘      │
├─────────────────────────────────┤
│  Quick Stats                    │
│  Customers: 142 · Products: 35  │
│  Total Credit: ₹25,800          │
├─────────────────────────────────┤
│  Last 7 Days Sales (Bar Chart)  │
│  [Mon][Tue][Wed][Thu][Fri][Sat][Sun]│
├─────────────────────────────────┤
│  Recent Bills                   │
│  ┌─────────────────────────────┐│
│  │ A101 · Ravi Kumar           ││
│  │ ₹690 · 11 Mar 10:30 AM      ││
│  └─────────────────────────────┘│
│  (10 items, scrollable)         │
├─────────────────────────────────┤
│  Top Customers                  │
│  1. Suresh Babu  ₹45,000        │
│  (5 items)                      │
└─────────────────────────────────┘
```

#### Components
- **4-card stat grid** — colored cards (green=sales, blue=collected, red=credit, orange=bills)
- **Quick stats row** — small pills/chips
- **Bar chart** — horizontal scroll, 7 bars, tap bar to see value tooltip
- **Recent bills list** — card rows, tap to open BillDetailScreen
- **Top customers list** — ranked list, tap to open CustomerDetailScreen
- **Pull-to-refresh** — reloads all data

#### Actions
| Action | Behavior |
|--------|----------|
| Tap recent bill row | Navigate → BillDetailScreen |
| Tap top customer row | Navigate → CustomerDetailScreen |
| Pull to refresh | Reload `GET /api/dashboard` |
| Tap [New Bill] FAB | Navigate → BillingFormScreen |

---

## 4. Products Module

### 4.1 Product List Screen

**Route/Screen:** `ProductListScreen`  
**API:** `GET /api/products`

#### Layout
```
┌─────────────────────────────────┐
│ ← Products              [+ Add] │
├─────────────────────────────────┤
│ [🔍 Search products...        ] │
│ [Active Only] toggle            │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │ [IMG] Classic Salted Chips  ││
│  │       ₹120.00 · box         ││
│  │       ● Active     [Edit]   ││
│  └─────────────────────────────┘│
│  (paginated list)               │
└─────────────────────────────────┘
```

#### Components
- **Search bar** — debounced, calls API on change
- **Active Only toggle** — filters active products
- **Product cards** — thumbnail, name, price, unit_type, status badge
- **Edit button** — navigates to ProductFormScreen (edit mode)
- **Swipe left to delete** — admin only, with confirmation dialog
- **FAB (+)** — navigates to ProductFormScreen (create mode)
- **Pagination** — infinite scroll / "Load More" button

---

### 4.2 Product Form Screen (Create / Edit)

**Route/Screen:** `ProductFormScreen`  
**API:** `POST /api/products` or `PUT /api/products/{id}`

#### Layout
```
┌─────────────────────────────────┐
│ ← New Product           [Save] │
├─────────────────────────────────┤
│  [Product Image — tap to pick] │
│                                 │
│  Product Name *                 │
│  [                            ] │
│                                 │
│  Price (₹) *                    │
│  [                            ] │
│                                 │
│  Unit Type *                    │
│  [box ▼] (picker)               │
│                                 │
│  Description                    │
│  [                            ] │
│                                 │
│  Active  [ ●──  ] (switch)      │
│                                 │
│  [  SAVE PRODUCT  ]             │
└─────────────────────────────────┘
```

#### Fields
| Field       | Input Type          | Validation          |
|------------|---------------------|---------------------|
| name       | Text                | Required            |
| price      | Numeric keyboard    | Required, ≥ 0       |
| unit_type  | Picker / Text       | Required            |
| description| Multi-line text     | Optional            |
| image      | Image picker        | Optional, max 2MB   |
| is_active  | Switch              | Edit mode only      |

---

## 5. Customers Module

### 5.1 Customer List Screen

**Route/Screen:** `CustomerListScreen`  
**API:** `GET /api/customers`

#### Layout
```
┌─────────────────────────────────┐
│ ← Customers             [+ Add] │
├─────────────────────────────────┤
│ [🔍 Search name/shop/mobile   ] │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │ Ravi Kumar                  ││
│  │ Ravi Stores · 9876543210    ││
│  │ Chennai · Credit: ₹1,500   ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

#### Components
- Search bar (name, shop, mobile, location)
- Customer card — tap to open CustomerDetailScreen
- Credit badge — highlighted red if credit > 0, green if extra > 0
- FAB (+) — create new customer
- Swipe left → Edit / Delete (admin only)

---

### 5.2 Customer Detail Screen

**Route/Screen:** `CustomerDetailScreen`  
**API:** `GET /api/customers/{id}`

#### Layout
```
┌─────────────────────────────────┐
│ ←  Ravi Kumar          [Edit]  │
├─────────────────────────────────┤
│  [Avatar/Initial]               │
│  Ravi Kumar                     │
│  Ravi Stores                    │
│  📱 9876543210                  │
│  📍 Chennai                    │
│                                 │
│  ┌──────────────────────────┐   │
│  │ Credit Balance: ₹1,500  │   │
│  │ Extra Amount:   ₹0.00   │   │
│  └──────────────────────────┘   │
│                                 │
│  Total Bills: 12                │
│  Total Spent: ₹45,000           │
├─────────────────────────────────┤
│  Recent Bills (last 20)         │
│  ┌─────────────────────────────┐│
│  │ A101 · ₹690 · 11 Mar       ││
│  │ Paid: ₹500 · Credit: ₹190  ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

#### Actions
- Tap bill row → BillDetailScreen
- [Edit] button → CustomerFormScreen (edit mode)
- [New Bill for customer] button → BillingFormScreen with customer pre-selected

---

### 5.3 Customer Form Screen (Create / Edit)

**Route/Screen:** `CustomerFormScreen`  
**API:** `POST /api/customers` or `PUT /api/customers/{id}`

#### Fields
| Field              | Input Type       | Validation       |
|-------------------|------------------|------------------|
| name              | Text             | Required         |
| shop_name         | Text             | Optional         |
| mobile            | Phone keyboard   | Required         |
| mobile_secondary  | Phone keyboard   | Optional         |
| location          | Text             | Optional         |
| credit_balance    | Numeric          | Optional, ≥ 0    |
| extra_amount      | Numeric          | Optional, ≥ 0, create only |

---

## 6. Billing Module (New Bill Flow)

### 6.1 Billing Form Screen

**Route/Screen:** `BillingFormScreen`  
**APIs:**
- `GET /api/customers/search?q=` (customer autocomplete)
- `GET /api/customers/{id}/credit` (credit info after selection)
- `GET /api/products/search?q=` (product autocomplete)
- `POST /api/billing/preview` (on submit)

#### Layout
```
┌─────────────────────────────────┐
│ ← New Bill                      │
├─────────────────────────────────┤
│  CUSTOMER                       │
│  [🔍 Search customer...       ] │
│  ┌─── Selected Customer ──────┐ │
│  │ Ravi Kumar (Ravi Stores)   │ │
│  │ Credit: ₹1,500 · Extra: ₹0│ │
│  └───────────────────────────┘ │
│  [+ Quick Add Customer]         │
├─────────────────────────────────┤
│  ITEMS                          │
│  [🔍 Search product to add... ]│
│                                 │
│  ┌─── Item Row ───────────────┐ │
│  │ Classic Salted Chips · box  │ │
│  │ Qty: [5  ] × ₹[120.00]    │ │
│  │ [☑ Custom] ₹[_____]       │ │
│  │ Total: ₹600.00    [🗑]     │ │
│  └───────────────────────────┘ │
│  [+ Add Another Item]           │
├─────────────────────────────────┤
│  SUMMARY                        │
│  Subtotal: ₹740.00              │
│  Discount: [50.00  ]            │
│  Total:    ₹690.00              │
│  Prev Credit: ₹1,500            │
│  Collected:  [500.00]           │
│  Credit Due: ₹190.00            │
├─────────────────────────────────┤
│  Notes: [optional...]           │
├─────────────────────────────────┤
│  [    PREVIEW BILL →   ]        │
└─────────────────────────────────┘
```

#### Component Details

**Customer Search:**
- Debounced text input triggers `GET /api/customers/search?q=`
- Dropdown list shows name + shop + mobile
- On selection: fetch `GET /api/customers/{id}/credit` to show credit/extra balance
- [+ Quick Add] opens CustomerFormScreen in a bottom sheet modal; on save, auto-selects new customer

**Product Search & Item Row:**
- Search triggers `GET /api/products/search?q=`
- Tap product to add as a new item row
- Each item row:
  - Product name + unit_type (read-only header)
  - Qty input (numeric, supports decimals)
  - Unit Price (pre-filled from product, editable)
  - Custom Price checkbox — when checked, additional price input appears
  - Live computed item total
  - Delete (trash icon) button
- Items list is scrollable; form uses sticky header approach on mobile

**Summary Section:**
- Real-time computation as user changes qty/price/discount/collected
- Discount: numeric input, applied to subtotal
- Collected amount: numeric input
- Shows: subtotal, discount, total, previous credit, credit due / extra change

**Preview Button:**
- Validates: customer selected, ≥1 item, collected_amount filled
- Calls `POST /api/billing/preview`
- On success: navigate to BillPreviewScreen passing `preview_token` + `previewData`
- On error: show inline error toast

---

### 6.2 Bill Preview Screen

**Route/Screen:** `BillPreviewScreen`  
**APIs:**
- `POST /api/billing/preview/whatsapp` (for WhatsApp share)
- `POST /api/billing/finalize` (to confirm and save)

#### Layout
```
┌─────────────────────────────────┐
│ ← Bill Preview           [Edit] │
├─────────────────────────────────┤
│  ⚠️  PREVIEW — Not saved yet    │
├─────────────────────────────────┤
│  Star Chips                     │
│  Bill Preview · {date}          │
│                                 │
│  Customer: Ravi Kumar           │
│  Ravi Stores · 9876543210       │
├─────────────────────────────────┤
│  ITEMS                          │
│  #  Name        Qty  Price  Total│
│  1  Salted Chip  5  ₹120  ₹600 │
│  2  Masala Chip  2  ₹70*  ₹140 │
│     (* = Custom Price)          │
├─────────────────────────────────┤
│  Subtotal:         ₹740.00      │
│  Discount:        -₹50.00       │
│  ─────────────────────────      │
│  Total:            ₹690.00      │
│                                 │
│  ┌──────────┐ ┌──────────┐      │
│  │Collected │ │ Credit   │      │
│  │ ₹500.00  │ │ ₹190.00  │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │Prev Credit│ │ Final Cr │      │
│  │ ₹1,500   │ │ ₹1,690   │      │
│  └──────────┘ └──────────┘      │
│                                 │
│  Notes: Delivered to shop       │
├─────────────────────────────────┤
│  ┌────────┐  ┌─────────────┐    │
│  │Thermal │  │  A4 / PDF   │    │
│  │ Print  │  │   Print     │    │
│  └────────┘  └─────────────┘    │
│  ┌────────┐  ┌─────────────┐    │
│  │WhatsApp│  │  App Share  │    │
│  │ Share  │  │             │    │
│  └────────┘  └─────────────┘    │
│                                 │
│  [   ✓ CONFIRM & CREATE BILL  ] │
│       (primary, large button)   │
└─────────────────────────────────┘
```

#### Component Details

**Preview Notice Banner:**
- Yellow/amber background
- Text: "Preview Mode — Review this bill carefully. It has not been saved yet."

**Items Table:**
- Custom price items show asterisk (*) and custom label

**Payment Summary Cards:**
- Collected — green card
- Credit Due — red card (only if > 0)
- Previous Credit — orange card (only if > 0)
- Extra Advance — purple card (only if > 0)
- Final Credit Balance — shown at bottom

**Action Buttons (4 options):**
| Button | Action |
|--------|--------|
| Thermal Print | Open ThermalPrintScreen (renders receipt layout) |
| A4 / PDF Print | Open A4PrintScreen (renders A4 invoice layout) |
| WhatsApp Share | Call `POST /api/billing/preview/whatsapp`, open `customer_whatsapp_url` |
| App Share | Call `POST /api/billing/preview/whatsapp`, use native Share sheet with `message` |

**[Back & Edit] (← header button):**
- Navigate back to BillingFormScreen
- The `preview_token` is still valid (30-min cache) — re-use form data

**[Confirm & Create Bill] button:**
- Shows loading spinner
- Calls `POST /api/billing/finalize { preview_token }`
- Disable button after first tap (prevent double-submit)
- On success: navigate to BillDetailScreen (replace BillPreviewScreen in stack)
- On error: show error alert, re-enable button

---

### 6.3 Bill Confirmed Screen / Bill Details

**Route/Screen:** `BillDetailScreen`  
**APIs:**
- `GET /api/bills/{id}` (load detail)
- `GET /api/bills/{id}/whatsapp` (WhatsApp share)
- `GET /api/bills/{id}/print` (print data)

#### Layout
```
┌─────────────────────────────────┐
│ ← Bill #A101         [Options⋮] │
├─────────────────────────────────┤
│  ✅ Bill Created Successfully   │  ← shown only after finalize
│                                 │
│  ┌──────────────────────────┐   │
│  │ CUSTOMER                 │   │
│  │ Ravi Kumar               │   │
│  │ Ravi Stores              │   │
│  │ 📱 9876543210             │   │
│  │ 📍 Chennai               │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │ BILL INFO                │   │
│  │ Bill #: A101             │   │
│  │ Date: 11 Mar 2024        │   │
│  │ Billed by: Admin         │   │
│  │ Status: ✅ completed      │   │
│  └──────────────────────────┘   │
│                                 │
│  ITEMS                          │
│  ┌─────────────────────────────┐│
│  │ 1. Classic Salted Chips     ││
│  │    box · Qty: 5 × ₹120.00  ││
│  │    Total: ₹600.00           ││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │ 2. Masala Chips             ││
│  │    box · Qty: 2 × ₹70.00*  ││
│  │    (* Custom Price)         ││
│  │    Total: ₹140.00           ││
│  └─────────────────────────────┘│
│                                 │
│  PAYMENT SUMMARY                │
│  Subtotal:       ₹740.00        │
│  Discount:      -₹50.00         │
│  ─────────────────────────      │
│  Total:          ₹690.00        │
│  Collected:     +₹500.00        │
│  Credit Due:     ₹190.00        │
│  Prev Credit:   ₹1,500.00       │
│                                 │
│  Notes: Delivered to shop       │
├─────────────────────────────────┤
│  ┌─────────┐  ┌─────────────┐   │
│  │ Thermal │  │  A4 / PDF   │   │
│  │  Print  │  │   Print     │   │
│  └─────────┘  └─────────────┘   │
│  ┌─────────┐  ┌─────────────┐   │
│  │ WhatsApp│  │ App Share   │   │
│  └─────────┘  └─────────────┘   │
└─────────────────────────────────┘
```

#### Options Menu (⋮)
- Edit Bill (admin or current user)
- Delete Bill (admin only, with confirmation)

#### Actions
| Action | Behavior |
|--------|----------|
| Thermal Print | `GET /api/bills/{id}/print` → open ThermalPrintScreen |
| A4 Print / PDF | `GET /api/bills/{id}/print` → open A4PrintScreen |
| WhatsApp | `GET /api/bills/{id}/whatsapp` → open `customer_whatsapp_url` |
| App Share | `GET /api/bills/{id}/whatsapp` → native Share.share(message) |
| Edit | Navigate to BillEditScreen |
| Delete | Confirm → `DELETE /api/bills/{id}` → navigate back to Bills list |

---

## 7. Bill History Module

### 7.1 Bill List Screen

**Route/Screen:** `BillListScreen`  
**API:** `GET /api/bills`  
**Tab:** Bills

#### Layout
```
┌─────────────────────────────────┐
│ Bills                  [Filter] │
├─────────────────────────────────┤
│ [🔍 Search bill number...     ] │
├─────────────────────────────────┤
│  SUMMARY (filtered)             │
│  Total: ₹1,45,000               │
│  Collected: ₹1,30,000           │
│  Credit: ₹15,000                │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │ A101 · Ravi Kumar           ││
│  │ Ravi Stores                 ││
│  │ ₹690 · Paid: ₹500 · Cr: ₹190││
│  │ 11 Mar 2024, 10:30 AM       ││
│  └─────────────────────────────┘│
│  (paginated, infinite scroll)   │
└─────────────────────────────────┘
```

#### Filter Bottom Sheet
Activated by [Filter] button — slides up from bottom:
```
┌─────────────────────────────────┐
│         FILTER BILLS            │
├─────────────────────────────────┤
│  From Date: [Date Picker      ] │
│  To Date:   [Date Picker      ] │
│  Customer:  [Dropdown / Search] │
│  Billed By: [Dropdown         ] │
│                                 │
│  [CLEAR]          [APPLY]       │
└─────────────────────────────────┘
```

#### Actions
- Tap bill row → BillDetailScreen
- Pull to refresh → reload list
- Infinite scroll pagination

---

## 8. User Management Module (Admin Only)

> Visible only when `user.role === 'admin'`

### 8.1 User List Screen

**Route/Screen:** `UserListScreen`  
**API:** `GET /api/users`

#### Layout
```
┌─────────────────────────────────┐
│ ← Users                 [+ Add] │
├─────────────────────────────────┤
│ [🔍 Search users...           ] │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │ Sales User                  ││
│  │ @sales1 · 9123456789        ││
│  │ Role: user  ● Active [Edit] ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

---

### 8.2 User Form Screen (Create / Edit)

**Route/Screen:** `UserFormScreen`  
**API:** `POST /api/users` or `PUT /api/users/{id}`

#### Fields
| Field                  | Input Type    | Notes                      |
|-----------------------|---------------|----------------------------|
| name                  | Text          | Required                   |
| username              | Text          | Required, unique           |
| mobile                | Phone         | Required, unique           |
| role                  | Picker        | admin / user               |
| is_active             | Switch        | Edit mode only             |
| password              | Secure text   | Required on create         |
| password_confirmation | Secure text   | Must match password        |

---

## 9. Shared Components

### 9.1 Bill Item Row (in Detail and Preview)
```
┌─────────────────────────────────────────────────┐
│  #  │ Product Name + Unit │ Qty │  Price  │ Total │
│  1  │ Salted Chips · box  │  5  │ ₹120.00 │₹600  │
└─────────────────────────────────────────────────┘
```
- Custom price rows show a purple "(Custom)" label

### 9.2 Payment Summary Block
Reusable component used in Preview and Detail screens:
- Rows: Subtotal, Discount (if > 0), **Total** (bold), Collected, Credit Due, Previous Credit, Extra Amount

### 9.3 Customer Credit Card
Small info card shown in Billing Form after customer selection:
```
┌─────────────────────────────────────┐
│  Ravi Kumar (Ravi Stores)            │
│  Credit Balance: ₹1,500   ← red    │
│  Extra Amount:   ₹0.00              │
└─────────────────────────────────────┘
```

### 9.4 Action Button Bar (4 buttons)
Reused in Preview and Detail screens:
```
[Thermal] [A4/PDF] [WhatsApp] [Share]
```

### 9.5 Loading & Empty States
- **Loading:** Centered spinner with subtle pulsing skeleton cards
- **Empty:** Illustration + message + action button (e.g., "No bills yet — Create your first bill")
- **Error:** Error message card with [Retry] button

### 9.6 Toast / Snackbar
- Success: green background, bottom of screen, auto-dismiss 3s
- Error: red background, auto-dismiss 5s

---

## 10. Navigation Structure

```
LoginScreen
    │ (login success)
    ▼
BottomTabNavigator
  ├── [📊] DashboardScreen
  │         └── BillDetailScreen (tap recent bill)
  │         └── CustomerDetailScreen (tap top customer)
  │
  ├── [📄] BillingFormScreen  ← New Bill (center tab, prominent)
  │         └── CustomerFormScreen (quick add, modal)
  │         └── BillPreviewScreen
  │                   └── ThermalPrintScreen (modal)
  │                   └── A4PrintScreen (modal)
  │                   └── BillDetailScreen (after finalize, replaces preview)
  │
  ├── [🧾] BillListScreen
  │         └── BillDetailScreen
  │                   └── BillEditScreen
  │
  └── [☰] MoreScreen (menu)
          ├── CustomerListScreen
          │       ├── CustomerDetailScreen
          │       └── CustomerFormScreen
          ├── ProductListScreen
          │       └── ProductFormScreen
          ├── UserListScreen (admin only)
          │       └── UserFormScreen
          └── Logout
```

**Back navigation behavior:**
- After `finalize`, BillPreviewScreen is replaced by BillDetailScreen (cannot go back to preview)
- BillingFormScreen is kept in stack when navigating to preview (Back & Edit works)

---

## 11. Color & Typography System

### Colors (matching web app)

| Token           | Value     | Usage                        |
|----------------|-----------|------------------------------|
| `primary`      | `#6C5CE7` | Accent, buttons, links       |
| `success`      | `#10b981` | Collected, active, confirmed |
| `danger`       | `#dc2626` | Credit, delete, errors       |
| `warning`      | `#f59e0b` | Previous credit, preview notice |
| `info`         | `#3b82f6` | Bills count, neutral info    |
| `bg`           | `#f9fafb` | Screen background            |
| `card`         | `#ffffff` | Card background              |
| `border`       | `#e5e7eb` | Dividers, card borders       |
| `text`         | `#111827` | Primary text                 |
| `text-muted`   | `#6b7280` | Secondary text, labels       |

### Typography

| Style        | Size  | Weight |
|-------------|-------|--------|
| Page title  | 20sp  | 700    |
| Section title| 15sp | 600    |
| Body        | 14sp  | 400    |
| Label       | 12sp  | 500    |
| Caption     | 11sp  | 400    |
| Button      | 16sp  | 600    |
| Amount      | 18sp  | 700    |

### Spacing
- Screen padding: 16dp
- Card padding: 14–16dp
- Section gap: 12dp
- Row gap: 8dp

---

## 12. Print & Share Flows

### 12.1 Thermal Print Screen

**Route/Screen:** `ThermalPrintScreen`  
**Data source:** `previewData` (from preview) or `GET /api/bills/{id}/print`

Receipt layout — 58mm / 80mm thermal width simulation:
```
┌────────────────────────┐
│      Star Chips        │
│   ─────────────────    │
│  Bill #A101            │
│  11 Mar 2024 10:30 AM  │
│  ─────────────────     │
│  Ravi Kumar            │
│  Ravi Stores           │
│  9876543210            │
│  ─────────────────     │
│  1. Salted Chips x5    │
│     ₹120 = ₹600        │
│  2. Masala Chips x2    │
│     ₹70* = ₹140        │
│  ─────────────────     │
│  Subtotal: ₹740        │
│  Discount: -₹50        │
│  Total:    ₹690        │
│  Paid:     ₹500        │
│  Credit:   ₹190        │
│  ─────────────────     │
│  Thank you!            │
└────────────────────────┘
```

**Actions:**
- [Print] — trigger device print dialog (WebView-based or native print API)
- [Share as Image] — screenshot the receipt and share via native share sheet

---

### 12.2 A4 / Normal Print Screen

**Route/Screen:** `A4PrintScreen`  
**Data source:** Same as thermal

Invoice-style full-page layout with:
- Company header: **Star Chips**
- Invoice # and date (right aligned)
- Customer details block
- Items table with columns: #, Product, Unit, Qty, Price, Custom, Total
- Totals section (subtotal, discount, total, collected, credit)
- Notes block
- Footer: "Thank you for your business"

**Actions:**
- [Print / Save PDF] — native print-to-PDF
- [Share PDF] — native share sheet

---

### 12.3 WhatsApp Share Flow

For **preview** (before save):
1. Tap [WhatsApp] on Preview screen
2. Call `POST /api/billing/preview/whatsapp { preview_token }`
3. Receive `customer_whatsapp_url` or `whatsapp_url`
4. Open URL → WhatsApp opens with pre-filled message

For **saved bill** (Detail screen):
1. Tap [WhatsApp] on Bill Detail screen
2. Call `GET /api/bills/{id}/whatsapp`
3. Open `customer_whatsapp_url` if customer mobile exists, else `whatsapp_url`

---

### 12.4 App Share Flow (Native Share Sheet)

1. Tap [App Share] (preview or detail)
2. Fetch WhatsApp API for the `message` string
3. Call native `Share.share({ message: text })` (React Native / Flutter)
4. User chooses app: SMS, Email, WhatsApp, Telegram, Copy, etc.

This allows sharing bills through **any** app the user has installed, not just WhatsApp.

---

## Summary of All Screens

| Screen                 | API Endpoint(s)                            | Auth  |
|-----------------------|---------------------------------------------|-------|
| LoginScreen           | POST /api/auth/login                        | None  |
| DashboardScreen       | GET /api/dashboard                          | Token |
| ProductListScreen     | GET /api/products                           | Token |
| ProductFormScreen     | POST or PUT /api/products                   | Token |
| CustomerListScreen    | GET /api/customers                          | Token |
| CustomerDetailScreen  | GET /api/customers/{id}                     | Token |
| CustomerFormScreen    | POST or PUT /api/customers                  | Token |
| BillingFormScreen     | GET /api/customers/search, /api/products/search, POST /api/billing/preview | Token |
| BillPreviewScreen     | GET /api/billing/preview/{token}, POST /api/billing/preview/whatsapp, POST /api/billing/finalize | Token |
| BillDetailScreen      | GET /api/bills/{id}, GET /api/bills/{id}/whatsapp, GET /api/bills/{id}/print | Token |
| BillListScreen        | GET /api/bills                              | Token |
| BillEditScreen        | PUT /api/bills/{id}                         | Token |
| ThermalPrintScreen    | (uses data passed from previous screen)     | Token |
| A4PrintScreen         | (uses data passed from previous screen)     | Token |
| UserListScreen        | GET /api/users                              | Admin |
| UserFormScreen        | POST or PUT /api/users                      | Admin |
