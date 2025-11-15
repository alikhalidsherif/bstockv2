# Agent 8: Inventory UI Navigation Flow

## User Journey Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HOME SCREEN                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  [Inventory Card] ───────────────────────────────────────────────┐   │   │
│  └──────────────────────────────────────────────────────────────────│───┘   │
└─────────────────────────────────────────────────────────────────────│─────┘
                                                                       │
                                                                       ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRODUCT LIST SCREEN                                  │
│  /inventory                                                                  │
│                                                                              │
│  [Search Bar] ──────────────────────────────────────────────────────────    │
│  [Category Filters: All | Clothing | Electronics | ...]                     │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Product   │  │   Product   │  │   Product   │  │   Product   │        │
│  │   [Image]   │  │   [Image]   │  │   [Image]   │  │   [Image]   │        │
│  │    Name     │  │    Name     │  │    Name     │  │    Name     │        │
│  │  $99.99     │  │  $49.99     │  │  $149.99    │  │  $29.99     │        │
│  │  Stock: 50  │  │  Stock: 5   │  │  Stock: 100 │  │  Stock: 0   │        │
│  │             │  │   [LOW]     │  │             │  │  [LOW]      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│         │                │                │                                  │
│    Long Press      Long Press        Long Press                             │
│         │                │                │                                  │
│         ↓                ↓                ↓                                  │
│  ┌─────────────────────────────────────────────┐                            │
│  │  • Edit Product                             │                            │
│  │  • Adjust Stock                             │                            │
│  │  • Delete Product                           │                            │
│  └─────────────────────────────────────────────┘                            │
│                                                                              │
│  [Vendors Icon] ──────────────────┐   [Grid/List Toggle]                    │
│  [+ FAB] ─────────────────────┐   │                                         │
└───────────────────────────────│───│─────────────────────────────────────────┘
                                │   │
                ┌───────────────┘   └────────────────┐
                ↓                                     ↓
┌─────────────────────────────────────┐  ┌──────────────────────────────────┐
│     PRODUCT FORM SCREEN              │  │    VENDOR LIST SCREEN            │
│  /inventory/product/new              │  │ /inventory/vendors               │
│  /inventory/product/:id              │  │                                  │
│                                      │  │  ┌─────────────────────────────┐ │
│  BASIC INFORMATION                   │  │  │ [A] ABC Suppliers           │ │
│  ┌────────────────────────────────┐  │  │  │     📧 abc@example.com      │ │
│  │ Product Name *                 │  │  │  │     📞 +1234567890          │ │
│  │ Sale Price *                   │  │  │  │     📍 123 Main St          │ │
│  │ Quantity *                     │  │  │  │     [⋮ Delete]              │ │
│  │ SKU *                          │  │  │  └─────────────────────────────┘ │
│  └────────────────────────────────┘  │  │                                  │
│                                      │  │  ┌─────────────────────────────┐ │
│  [→ Advanced Options]                │  │  │ [X] XYZ Distributors        │ │
│     ├─ Product Image (tap to pick)  │  │  │     📧 xyz@example.com      │ │
│     ├─ Description                  │  │  │     📞 +9876543210          │ │
│     ├─ Category                     │  │  └─────────────────────────────┘ │
│     ├─ Vendor (dropdown)            │  │                                  │
│     ├─ Purchase Price               │  │  [+ FAB] ────────┐               │
│     ├─ Low Stock Alert Level        │  └──────────────────│───────────────┘
│     └─ Variant Attributes           │                     │
│        [Size: Large] [x]            │                     ↓
│        [+ Add Attribute]            │          ┌─────────────────────────┐
│                                      │          │  ADD VENDOR DIALOG      │
│  [Create Product / Update Product]  │          │  ┌───────────────────┐  │
│                                      │          │  │ Vendor Name *     │  │
│  Actions (Edit mode):                │          │  │ Email             │  │
│  [Adjust Stock] [Delete]            │          │  │ Phone             │  │
└──────────────────────────────────────┘          │  │ Address           │  │
                 │                                │  │ Notes             │  │
                 │                                │  └───────────────────┘  │
                 ↓                                │  [Cancel] [Add]         │
┌─────────────────────────────────────┐          └─────────────────────────┘
│   STOCK ADJUSTMENT SCREEN            │
│  /inventory/stock-adjustment/:id     │
│                                      │
│  Product: Blue T-Shirt               │
│  Total Stock: 100                    │
│  ───────────────────────────────────│
│                                      │
│  ┌────────────────────────────────┐ │
│  │ Variant: Size Large            │ │
│  │ SKU: BLU-TSH-L                 │ │
│  │                                │ │
│  │ Current: 50    →    New: 55    │ │
│  │                                │ │
│  │  [−]      +5        [+]        │ │
│  │                                │ │
│  │ Reason: ___________________    │ │
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ Variant: Size Medium [LOW]     │ │
│  │ SKU: BLU-TSH-M                 │ │
│  │                                │ │
│  │ Current: 5     →    New: 10    │ │
│  │                                │ │
│  │  [−]      +5        [+]        │ │
│  │                                │ │
│  │ Reason: ___________________    │ │
│  └────────────────────────────────┘ │
│                                      │
│  [Bulk Adjustment Icon]              │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ Reason for all adjustments:    │ │
│  │ Stock count correction         │ │
│  └────────────────────────────────┘ │
│                                      │
│  [Apply Adjustments]                 │
└──────────────────────────────────────┘
```

## Navigation Routes

### Primary Routes
| Route | Screen | Purpose |
|-------|--------|---------|
| `/inventory` | Product List | Browse all products with search/filter |
| `/inventory/product/new` | Product Form | Create new product |
| `/inventory/product/:id` | Product Form | Edit existing product |
| `/inventory/stock-adjustment/:productId` | Stock Adjustment | Adjust stock for all variants |
| `/inventory/vendors` | Vendor List | Manage vendors |

### Entry Points
1. **From Home Screen** → Tap "Inventory" card → Product List
2. **From Bottom Nav** (future) → Tap "Inventory" tab → Product List

### Exit Points
1. **Back to Home** → Use back button from Product List
2. **Back to List** → Use back button from any detail screen
3. **After Save** → Auto-navigate back to Product List

## User Interactions

### Product List Screen

#### Primary Actions
- **Tap Product Card** → Navigate to Edit Product
- **Tap + FAB** → Navigate to Add Product
- **Tap Vendors Icon** → Navigate to Vendor List
- **Tap Grid/List Toggle** → Switch view mode
- **Type in Search** → Filter products
- **Tap Category Filter** → Filter by category
- **Pull Down** → Refresh products

#### Secondary Actions (Long-press or Menu)
- **Edit Product** → Navigate to Edit Product
- **Adjust Stock** → Navigate to Stock Adjustment
- **Delete Product** → Show confirmation → Delete → Refresh list

### Product Form Screen

#### Primary Actions
- **Tap Image Area** → Open image picker → Select image
- **Tap Advanced Options** → Expand/collapse section
- **Tap Vendor Dropdown** → Select vendor
- **Tap Add Attribute** → Show dialog → Add variant attribute
- **Tap Save Button** → Validate → Save → Navigate back

#### Secondary Actions (Edit Mode Only)
- **Tap Adjust Stock Icon** → Navigate to Stock Adjustment
- **Tap Delete Icon** → Show confirmation → Delete → Navigate back

### Stock Adjustment Screen

#### Primary Actions
- **Tap + Button** → Increment adjustment
- **Tap − Button** → Decrement adjustment
- **Type in Reason** → Set adjustment reason
- **Tap Bulk Icon** → Show bulk dialog → Apply to all
- **Tap Apply Button** → Submit all adjustments → Navigate back

### Vendor List Screen

#### Primary Actions
- **Tap + FAB** → Show Add Vendor dialog
- **Tap Vendor Card** → Show Edit Vendor dialog
- **Pull Down** → Refresh vendors

#### Secondary Actions
- **Tap Delete in Menu** → Show confirmation → Delete vendor

## State Management Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                      InventoryProvider                            │
│                                                                   │
│  State:                                                           │
│  • products: List<Product>                                        │
│  • vendors: List<Vendor>                                          │
│  • isLoading: bool                                                │
│  • error: String?                                                 │
│  • searchQuery: String?                                           │
│  • categoryFilter: String?                                        │
│                                                                   │
│  Methods:                                                         │
│  • loadProducts()        → GET /products                          │
│  • getProduct(id)        → GET /products/:id                      │
│  • createProduct()       → POST /products                         │
│  • updateProduct()       → PUT /products/:id                      │
│  • deleteProduct()       → DELETE /products/:id                   │
│  • adjustStock()         → POST /variants/:id/adjust-stock        │
│  • loadVendors()         → GET /vendors                           │
│  • createVendor()        → POST /vendors                          │
│  • deleteVendor()        → DELETE /vendors/:id                    │
│  • uploadImage()         → POST /products/upload-image            │
│  • setSearchQuery()      → Update filter, notify listeners        │
│  • setCategoryFilter()   → Update filter, notify listeners        │
└──────────────────────────────────────────────────────────────────┘
                                    │
                                    │ notifyListeners()
                                    ↓
┌──────────────────────────────────────────────────────────────────┐
│                     Consumer<InventoryProvider>                   │
│                                                                   │
│  UI rebuilds when:                                                │
│  • Products loaded/updated/deleted                                │
│  • Vendors loaded/created/deleted                                 │
│  • Search query changed                                           │
│  • Category filter changed                                        │
│  • Loading state changed                                          │
│  • Error occurred                                                 │
└──────────────────────────────────────────────────────────────────┘
```

## Error Handling

### Network Errors
```
User Action → API Call Fails
            ↓
Provider sets error: "Failed to load products: Network error"
            ↓
UI shows error state with "Retry" button
            ↓
User taps "Retry" → loadProducts() called again
```

### Validation Errors
```
User taps "Save" → Form validation fails
                 ↓
Required field shows error: "Product name is required"
                 ↓
User corrects input → Validation passes
                    ↓
API call proceeds
```

### Delete Confirmations
```
User taps "Delete" → Show dialog: "Are you sure?"
                   ↓
User taps "Delete" → API call → Success → Navigate back + SnackBar
                   ↓
User taps "Cancel" → Dialog closes, no action
```

## Success Indicators

### Visual Feedback
- ✅ **SnackBar Messages**
  - "Product created successfully" (green)
  - "Product updated successfully" (green)
  - "Product deleted successfully" (green)
  - "Stock adjusted successfully" (green)
  - "Error: [message]" (red)

- ✅ **Loading Indicators**
  - CircularProgressIndicator during API calls
  - Button shows spinner instead of text
  - List shows skeleton/spinner on first load

- ✅ **Low Stock Badges**
  - Red "LOW" or "LOW STOCK" badge
  - Visible when `quantity <= min_stock_level`

- ✅ **Empty States**
  - "No products found" with icon
  - "No vendors yet" with helpful message

## Keyboard Shortcuts (Future Enhancement)

For desktop/web versions:
- `Ctrl+F` → Focus search bar
- `Ctrl+N` → New product
- `Esc` → Close dialog/go back
- `Enter` → Submit form

## Deep Linking Support (Future)

```
bstock://inventory
bstock://inventory/product/123
bstock://inventory/vendors
bstock://inventory/stock-adjustment/123
```

---

**Navigation Flow Complete** ✅

All screens are fully integrated with proper back stack management, state persistence, and error recovery.
