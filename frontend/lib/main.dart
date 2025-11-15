import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/analytics_provider.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sync service
  final syncService = SyncService();
  await syncService.initialize();

  runApp(MyApp(syncService: syncService));
}

class MyApp extends StatelessWidget {
  final SyncService syncService;

  const MyApp({Key? key, required this.syncService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        ChangeNotifierProvider.value(
          value: syncService,
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Bstock',
        theme: ThemeData(
          primaryColor: AppConfig.primaryColor,
          scaffoldBackgroundColor: AppConfig.backgroundColor,
          fontFamily: 'Roboto',
        ),
        routerConfig: router,
      ),
    );
  }
}
