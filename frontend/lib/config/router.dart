import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_wizard.dart';
import '../screens/inventory/product_list_screen.dart';
import '../screens/inventory/product_form_screen.dart';
import '../screens/inventory/stock_adjustment_screen.dart';
import '../screens/inventory/vendor_list_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/pos/checkout_screen.dart';
import '../screens/pos/receipt_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingWizard(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    // Inventory routes
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const ProductListScreen(),
    ),
    GoRoute(
      path: '/inventory/product/new',
      builder: (context, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/inventory/product/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProductFormScreen(productId: id);
      },
    ),
    GoRoute(
      path: '/inventory/stock-adjustment/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId']!;
        return StockAdjustmentScreen(productId: productId);
      },
    ),
    GoRoute(
      path: '/inventory/vendors',
      builder: (context, state) => const VendorListScreen(),
    ),
    // POS routes
    GoRoute(
      path: '/pos',
      builder: (context, state) => const POSScreen(),
    ),
    GoRoute(
      path: '/pos/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/pos/receipt/:saleId',
      builder: (context, state) {
        final saleId = state.pathParameters['saleId']!;
        return ReceiptScreen(saleId: saleId);
      },
    ),
  ],
);
