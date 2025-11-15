# Agents 8, 9, 10: Flutter Frontend (Combined Brief)

Due to tight timeline, here are streamlined specs for the remaining 3 Flutter agents.

---

## AGENT 8: Flutter Inventory UI (Day 2, 8-10 hours)

**Dependencies**: Agents 4 (Inventory API), 7 (Auth)

### Key Deliverables:

1. **Product List Screen** (`lib/screens/inventory/product_list_screen.dart`)
   - Grid/list view of products with images
   - Search bar for filtering
   - Category filter dropdown
   - Low stock indicator badges
   - FAB to add new product

2. **Add/Edit Product Screen** (`lib/screens/inventory/product_form_screen.dart`)
   - Progressive disclosure design (basic fields first)
   - Name, Sale Price, Quantity (required)
   - Expandable: Image, Category, Vendor, Purchase Price
   - Variant management (sizes, colors)
   - Image picker for product photos

3. **Stock Adjustment Screen** (`lib/screens/inventory/stock_adjustment_screen.dart`)
   - List of variants
   - +/- buttons for quick adjustments
   - Bulk adjustment option
   - Reason field for adjustments

4. **Vendor Management** (`lib/screens/inventory/vendor_list_screen.dart`)
   - Simple list of vendors
   - Add vendor dialog
   - Contact info display

5. **Services & Providers**:
   - `lib/services/inventory_service.dart` - API calls
   - `lib/providers/inventory_provider.dart` - State management
   - `lib/models/product.dart`, `variant.dart`, `vendor.dart`

### Key Features:
- Product CRUD with image uploads
- Variant management UI (attributes as chips)
- Low stock alerts (red badges when qty <= min)
- Search and filter
- Respects plan limits (shows upgrade prompt at limit)

---

## AGENT 9: Flutter POS UI (Day 2-3, 10-12 hours)

**Dependencies**: Agents 5 (Sales API), 8 (Inventory data)

### Key Deliverables:

1. **POS Screen** (`lib/screens/pos/pos_screen.dart`)
   - Two-panel layout (product grid + cart sidebar)
   - Product cards with image, name, price
   - Tap to add to cart
   - Search products by name/SKU
   - Barcode scanner button

2. **Cart Widget** (`lib/widgets/cart_widget.dart`)
   - Itemized list with product names
   - +/- steppers for quantity adjustment
   - Remove item button
   - Running total at bottom
   - Large "Charge" button (always visible)

3. **Checkout Screen** (`lib/screens/pos/checkout_screen.dart`)
   - Payment method selector (Cash, Mobile Money, Bank)
   - Optional payment proof camera
   - Confirm button
   - Receipt preview

4. **Receipt Screen** (`lib/screens/pos/receipt_screen.dart`)
   - Display PDF receipt from backend
   - Native share button
   - Print option (if available)

5. **Barcode Scanner** (`lib/services/barcode_service.dart`)
   - Use `mobile_scanner` package
   - Scan barcode and add to cart
   - Fallback to manual SKU entry

6. **Services & Providers**:
   - `lib/services/sales_service.dart` - Process sale API
   - `lib/providers/cart_provider.dart` - Cart state
   - `lib/models/sale.dart`, `sale_item.dart`

### Key Features:
- Fast one-tap add to cart
- Real-time total calculation
- Barcode scanning
- Payment proof photo capture
- PDF receipt sharing
- Stock validation (shows "Out of stock" if qty = 0)

---

## AGENT 10: Flutter Offline & Analytics (Day 3, 10-12 hours)

**Dependencies**: Agents 6 (Analytics API), 9 (POS)

### Part A: Offline Sync (CRITICAL)

1. **Isar Database Schema** (`lib/database/isar_schema.dart`)
   ```dart
   @collection
   class LocalProduct {
     Id? id;
     String? serverId;
     String? name;
     double? salePrice;
     int? quantity;
     bool isSynced;
   }

   @collection
   class LocalSale {
     Id? id;
     String? serverId;
     double? totalAmount;
     String? paymentMethod;
     bool isSynced;
     DateTime? createdAt;
     List<LocalSaleItem> items;
   }
   ```

2. **Sync Service** (`lib/services/sync_service.dart`)
   - Background worker checking connectivity
   - Queue offline sales in Isar
   - Auto-sync when online detected
   - Conflict resolution logic
   - Progress indicators

3. **Connectivity Monitor**
   - Use `connectivity_plus` package
   - Stream listener in app root
   - Trigger sync on connect
   - Show offline banner when disconnected

### Part B: Analytics Dashboard

1. **Analytics Dashboard** (`lib/screens/analytics/dashboard_screen.dart`)
   - Date range picker (Today, 7 Days, 30 Days, Custom)
   - Key metric cards:
     - Total Revenue (large number)
     - Gross Profit (with margin %)
     - Transactions count
     - Items sold
   - Daily sales line chart (use `fl_chart` package)

2. **Top Products Screen** (`lib/screens/analytics/top_products_screen.dart`)
   - Toggle: Top Selling vs Most Profitable
   - List of products with metrics
   - Visual ranking (1st, 2nd, 3rd badges)

3. **Services & Providers**:
   - `lib/services/analytics_service.dart`
   - `lib/providers/analytics_provider.dart`
   - Feature gate check (show upgrade prompt if on free plan)

### Key Features:
- Full offline POS capability
- Automatic background sync
- Clear sync status indicators
- Beautiful analytics charts
- Feature gate enforcement (analytics)
- Date range filtering

---

## Shared Flutter Components (All Agents)

### Custom Widgets (lib/widgets/)

**custom_button.dart**:
```dart
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppConfig.primaryColor,
        minimumSize: Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Text(text, style: TextStyle(fontSize: 16)),
    );
  }
}
```

**custom_text_field.dart**:
```dart
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }
}
```

---

## Flutter Packages Required

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  go_router: ^13.0.0
  http: ^1.1.2
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  path_provider: ^2.1.1
  image_picker: ^1.0.4
  mobile_scanner: ^3.5.2
  fl_chart: ^0.65.0
  connectivity_plus: ^5.0.2
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7
  isar_generator: ^3.1.0+1
  flutter_lints: ^3.0.1
```

---

## Critical Integration Points

1. **Agent 8 → Agent 9**: Product data flows to POS screen
2. **Agent 9 → Agent 10**: Sales are queued offline in Isar
3. **Agent 10 ↔ Backend**: Sync service talks to all backend APIs
4. **All → Agent 7**: All screens use AuthProvider for tokens

---

## Testing for Flutter Agents

Each agent should test:
- [ ] UI matches design specs (colors, spacing, fonts)
- [ ] API integration working (can hit backend)
- [ ] Error handling (network failures show snackbars)
- [ ] Loading states display correctly
- [ ] Navigation flows work
- [ ] Forms validate input
- [ ] Images upload successfully
- [ ] Offline mode works (Agent 10)
- [ ] Real devices tested (Android & iOS)

---

## Success Criteria (All Flutter Agents)

1. ✅ Complete UI implementation per design specs
2. ✅ All API endpoints integrated
3. ✅ State management working
4. ✅ Offline sync functional
5. ✅ No crashes or memory leaks
6. ✅ Performance acceptable (60fps)
7. ✅ Works on Android & iOS

---

## Combined Timeline (Agents 8, 9, 10)

- **Day 2 Morning**: Agent 8 starts (inventory UI)
- **Day 2 Afternoon**: Agent 9 starts (POS UI)
- **Day 2 Evening**: Agent 8 completes, Agent 9 ongoing
- **Day 3 Morning**: Agent 10 starts (offline + analytics)
- **Day 3 Afternoon**: Integration testing
- **Day 3 Evening**: All Flutter agents complete

**Total Estimated Time: 28-34 hours across 3 agents**

---

## Quick Start Commands for Each Agent

**Agent 8**:
```bash
cd frontend
flutter pub get
# Create inventory screens and services
flutter run
```

**Agent 9**:
```bash
# Add mobile_scanner and image_picker
flutter pub add mobile_scanner image_picker
# Create POS screens
flutter run
```

**Agent 10**:
```bash
# Generate Isar schemas
flutter pub run build_runner build
# Add connectivity and charts
flutter pub add connectivity_plus fl_chart
flutter run
```
