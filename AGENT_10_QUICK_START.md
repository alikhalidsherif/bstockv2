# Agent 10 - Quick Start Guide

## Immediate Next Steps

### 1. Generate Isar Database Code

The Isar database schema has been created, but the generated code files need to be built:

```bash
cd frontend
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate:
- `lib/database/isar_schema.g.dart`

**Expected output:**
```
[INFO] Generating build script...
[INFO] Generating build script completed, took 342ms
[INFO] Creating build script snapshot......
[INFO] Creating build script snapshot... completed, took 8.7s
[INFO] Building new asset graph...
[INFO] Building new asset graph completed, took 592ms
[INFO] Checking for unexpected pre-existing outputs....
[INFO] Checking for unexpected pre-existing outputs. completed, took 1ms
[INFO] Running build...
[INFO] Generating SDK summary...
[INFO] 3.0s elapsed, 0/1 actions completed.
[INFO] Running build completed, took 3.1s
[INFO] Caching finalized dependency graph...
[INFO] Caching finalized dependency graph completed, took 35ms
[INFO] Succeeded after 3.1s with 2 outputs (4 actions)
```

### 2. Run the Application

```bash
# Connect device or start emulator
flutter devices

# Run on connected device
flutter run

# Or run in release mode
flutter run --release
```

### 3. Test Offline Sync

1. Open the app and complete onboarding
2. Navigate to POS screen
3. Add items to cart
4. Turn OFF internet/WiFi
5. Process sale through checkout
6. Observe "Sale saved offline" message
7. Check home screen for connectivity banner showing pending sales
8. Turn ON internet/WiFi
9. Observe automatic sync and banner disappearing

### 4. Test Analytics

1. Ensure you're logged in with a paid plan account
2. Navigate to Analytics from home screen
3. Select different date ranges
4. View metric cards
5. Scroll to daily sales chart
6. Tap "View Top Products"
7. Toggle between Top Selling and Most Profitable

## Troubleshooting

### Build Runner Issues

**Problem:** `build_runner` hangs or fails

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Isar Database Issues

**Problem:** "Isar instance is not open" or database errors

**Solution:**
- Check that `main()` is async and calls `syncService.initialize()`
- Verify `isar_schema.g.dart` was generated
- Try uninstalling and reinstalling the app to reset database

### Connectivity Issues

**Problem:** Offline sync not triggering

**Solution:**
- Ensure `connectivity_plus` package is installed
- Check device permissions (Android needs ACCESS_NETWORK_STATE)
- Try toggling airplane mode on real device
- Check logs for connectivity events: `flutter logs | grep -i connectivity`

### Analytics Not Loading

**Problem:** Empty analytics or errors

**Solution:**
- Verify backend is running (`http://localhost:8080`)
- Check user has proper subscription plan (not 'free')
- Ensure sales exist in database
- Check API endpoints are accessible
- Review logs for API errors

## Key Files Reference

### Offline Sync
- Schema: `lib/database/isar_schema.dart`
- Service: `lib/services/sync_service.dart`
- Integration: `lib/screens/pos/checkout_screen.dart`

### Analytics
- Service: `lib/services/analytics_service.dart`
- Provider: `lib/providers/analytics_provider.dart`
- Dashboard: `lib/screens/analytics/dashboard_screen.dart`
- Top Products: `lib/screens/analytics/top_products_screen.dart`

### Connectivity
- Widgets: `lib/widgets/connectivity_indicator.dart`
- Integration: `lib/main.dart`, `lib/screens/home/home_screen.dart`

## Testing Scenarios

### Offline Mode

```
Scenario 1: Offline Sale
1. Disable internet
2. Add product to cart
3. Complete checkout
4. Verify sale queued (check banner)
5. Enable internet
6. Verify auto-sync (banner disappears)

Scenario 2: Failed Online Sale
1. Ensure internet is on
2. Stop backend server
3. Add product to cart
4. Complete checkout
5. Observe sale queued (API failed)
6. Start backend server
7. Tap "Sync Now" in banner
8. Verify sync succeeds
```

### Analytics

```
Scenario 1: Free User
1. Login with free plan account
2. Navigate to Analytics
3. Verify upgrade prompt shown
4. Cannot access dashboard

Scenario 2: Paid User
1. Login with standard/premium account
2. Navigate to Analytics
3. View dashboard with metrics
4. Change date range
5. View daily sales chart
6. Navigate to Top Products
7. Toggle between quantity/profit
```

## Important Notes

1. **First Run**: The app will create the Isar database automatically on first launch
2. **Database Location**: Stored in app documents directory (not visible to user)
3. **Sync Frequency**: Automatic on connectivity change + manual via button
4. **Chart Performance**: fl_chart handles up to ~100 data points smoothly
5. **Feature Gates**: Analytics requires standard or premium plan

## Development Workflow

```bash
# Make code changes
vim lib/some_file.dart

# Hot reload (if app is running)
# Press 'r' in terminal

# Or restart app
# Press 'R' in terminal

# Check logs
flutter logs

# Format code
flutter format .

# Analyze code
flutter analyze
```

## Production Deployment

### Pre-Deploy Checklist

- [ ] Run `flutter pub run build_runner build`
- [ ] Run `flutter analyze` (fix all issues)
- [ ] Run `flutter test` (all tests pass)
- [ ] Test on physical Android device
- [ ] Test on physical iOS device
- [ ] Test offline mode thoroughly
- [ ] Verify analytics with real data
- [ ] Update version in `pubspec.yaml`
- [ ] Update `CHANGELOG.md`

### Build Commands

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Mac)
flutter build ios --release
```

## Support

For issues or questions:
1. Check `AGENT_10_COMPLETION_REPORT.md` for detailed documentation
2. Review `AGENT_8_9_10_FLUTTER_SPECS.md` for original requirements
3. Check backend API documentation in backend README files
4. Review other agent completion reports for dependencies

---

**Last Updated:** 2025-11-15
**Agent:** Agent 10
