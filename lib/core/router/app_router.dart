import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/incident_log_admin_page.dart';
import '../../features/admin/presentation/pages/user_management_page.dart';
import '../../features/admin/presentation/pages/warehouse_verification_page.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/pages/create_new_password_page.dart';
import '../../features/auth/presentation/pages/help_page.dart';
import '../../features/auth/presentation/pages/email_verification_pending_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/location_permission_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/mitra_profile_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/umkm_profile_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/booking/presentation/pages/booking_history_page.dart';
import '../../features/dashboard_mitra/presentation/pages/mitra_dashboard_page.dart';
import '../../features/dashboard_mitra/presentation/pages/revenue_report_page.dart';
import '../../features/dashboard_mitra/presentation/pages/warehouse_health_page.dart';
import '../../features/notification/presentation/pages/incident_log_page.dart';
import '../../features/telemetry/presentation/pages/temperature_monitoring_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_detail_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_list_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_registration_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_search_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_edit_page.dart';
import '../../features/warehouse/presentation/pages/umkm_home_page.dart';
import '../constants/route_constants.dart';
import '../widgets/shell_scaffolds.dart';
import 'route_guard.dart';

// -----------------------------------------------------------------------------
// Public provider
// -----------------------------------------------------------------------------

/// Provides the app's single [GoRouter] instance.
///
/// The router is built once per provider lifecycle and listens to
/// [authProvider] via a `ValueNotifier` that triggers a re-evaluation of the
/// `redirect` function whenever auth state changes. This avoids rebuilding
/// the router itself on every state change.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: _routes,
  );
});

// -----------------------------------------------------------------------------
// Redirect / guard
// -----------------------------------------------------------------------------

String? _redirect(Ref ref, GoRouterState state) {
  return computeRedirect(
    authState: ref.read(authProvider),
    location: state.uri.path,
  );
}

// -----------------------------------------------------------------------------
// Routes
// -----------------------------------------------------------------------------

final List<RouteBase> _routes = <RouteBase>[
  // Root splash — rendered only briefly while the guard decides where to go.
  GoRoute(
    path: RouteConstants.splash,
    builder: (context, state) => const SplashPage(),
  ),

  // Auth pages (no shell).
  GoRoute(
    path: RouteConstants.login,
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    path: RouteConstants.register,
    builder: (context, state) => const RegisterPage(),
  ),
  GoRoute(
    path: RouteConstants.forgotPassword,
    builder: (context, state) => const ForgotPasswordPage(),
  ),
  GoRoute(
    path: RouteConstants.createNewPassword,
    builder: (context, state) {
      final showExpired =
          state.uri.queryParameters['expired'] == 'true';
      return CreateNewPasswordPage(showExpired: showExpired);
    },
  ),
  GoRoute(
    path: RouteConstants.emailVerificationPending,
    builder: (context, state) {
      final email = state.uri.queryParameters['email'] ?? '';
      return EmailVerificationPendingPage(email: email);
    },
  ),
  GoRoute(
    path: RouteConstants.locationPermission,
    builder: (context, state) => const LocationPermissionPage(),
  ),

  // Shared detail page — no shell (navigated from inside UMKM flow).
  GoRoute(
    path: RouteConstants.warehouseDetail,
    builder: (context, state) => WarehouseDetailPage(
      warehouseId: state.pathParameters['id'] ?? '',
    ),
  ),

  // --- UMKM shell ----------------------------------------------------------
  ShellRoute(
    builder: (context, state, child) => UmkmShell(child: child),
    routes: [
      GoRoute(
        path: RouteConstants.umkmHome,
        builder: (context, state) => const UmkmHomePage(),
      ),
      GoRoute(
        path: RouteConstants.umkmSearch,
        builder: (context, state) => const WarehouseSearchPage(),
      ),
      GoRoute(
        path: RouteConstants.umkmBookings,
        builder: (context, state) => const BookingHistoryPage(),
      ),
      // Index page for the monitoring tab — shows incident logs.
      GoRoute(
        path: '/umkm/monitoring',
        builder: (context, state) => const IncidentLogPage(),
      ),
      GoRoute(
        path: RouteConstants.umkmMonitoring,
        builder: (context, state) => TemperatureMonitoringPage(
          warehouseId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RouteConstants.umkmNotifications,
        builder: (context, state) => const IncidentLogPage(),
      ),
      GoRoute(
        path: RouteConstants.umkmHelp,
        builder: (context, state) => const HelpPage(),
      ),
      GoRoute(
        path: RouteConstants.umkmProfile,
        builder: (context, state) => const UmkmProfilePage(),
      ),
    ],
  ),

  // --- Mitra shell ---------------------------------------------------------
  ShellRoute(
    builder: (context, state, child) => MitraShell(child: child),
    routes: [
      GoRoute(
        path: RouteConstants.mitraDashboard,
        builder: (context, state) => const MitraDashboardPage(),
      ),
      GoRoute(
        path: '/mitra/revenue-report',
        builder: (context, state) => const RevenueReportPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraWarehouses,
        builder: (context, state) => const WarehouseListPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraTransactions,
        builder: (context, state) => const BookingHistoryPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraWarehouseRegister,
        builder: (context, state) => const WarehouseRegistrationPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraWarehouseEdit,
        builder: (context, state) => WarehouseEditPage(
          warehouseId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: RouteConstants.mitraWarehouseHealth,
        builder: (context, state) => WarehouseHealthPage(
          warehouseId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/mitra/incidents',
        builder: (context, state) => const IncidentLogPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraNotifications,
        builder: (context, state) => const IncidentLogPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraHelp,
        builder: (context, state) => const HelpPage(),
      ),
      GoRoute(
        path: RouteConstants.mitraProfile,
        builder: (context, state) => const MitraProfilePage(),
      ),
    ],
  ),

  // --- Admin shell ---------------------------------------------------------
  ShellRoute(
    builder: (context, state, child) => AdminShell(child: child),
    routes: [
      GoRoute(
        path: RouteConstants.adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: RouteConstants.adminUsers,
        builder: (context, state) => const UserManagementPage(),
      ),
      GoRoute(
        path: RouteConstants.adminWarehouses,
        builder: (context, state) => const WarehouseVerificationPage(),
      ),
      GoRoute(
        path: RouteConstants.adminIncidents,
        builder: (context, state) => const IncidentLogAdminPage(),
      ),
    ],
  ),
];

// -----------------------------------------------------------------------------
// Auth refresh bridge — keeps GoRouter's redirect in sync with Riverpod
// -----------------------------------------------------------------------------

/// A [ChangeNotifier] that fires whenever [authProvider] emits a new state.
/// Wired to GoRouter via `refreshListenable`.
class _AuthRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription<AsyncValue<UserEntity?>> _sub;

  _AuthRefreshNotifier(Ref ref) {
    _sub = ref.listen<AsyncValue<UserEntity?>>(
      authProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// Placeholders — replaced by feature pages in later tasks
// -----------------------------------------------------------------------------
