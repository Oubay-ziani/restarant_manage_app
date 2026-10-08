import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/main_navigation_screen.dart';
import '../../features/orders/screens/new_order_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/screens/payment_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/new-order/:tableNumber',
        builder: (context, state) {
          final tableNumberStr = state.pathParameters['tableNumber'] ?? '1';
          return NewOrderScreen(tableNumber: int.parse(tableNumberStr));
        },
      ),
      GoRoute(
        path: '/order-detail/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/payment/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return PaymentScreen(orderId: orderId);
        },
      ),
    ],
  );
});
