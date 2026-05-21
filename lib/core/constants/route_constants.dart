/// Named route path constants for GoRouter.
/// All navigation paths are defined here to avoid magic strings.
class RouteConstants {
  RouteConstants._();

  // ---------------------------------------------------------------------------
  // Root / Auth
  // ---------------------------------------------------------------------------
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String createNewPassword = '/create-new-password';
  static const String emailVerificationPending = '/email-verification-pending';
  static const String locationPermission = '/location-permission';

  // ---------------------------------------------------------------------------
  // UMKM Shell
  // ---------------------------------------------------------------------------
  static const String umkmShell = '/umkm';
  static const String umkmHome = '/umkm/home';
  static const String umkmSearch = '/umkm/search';
  static const String umkmBookings = '/umkm/bookings';
  static const String umkmMonitoring = '/umkm/monitoring/:id';
  static const String umkmProfile = '/umkm/profile';

  // ---------------------------------------------------------------------------
  // Mitra Shell
  // ---------------------------------------------------------------------------
  static const String mitraShell = '/mitra';
  static const String mitraDashboard = '/mitra/dashboard';
  static const String mitraWarehouses = '/mitra/warehouses';
  static const String mitraTransactions = '/mitra/transactions';
  static const String mitraWarehouseRegister = '/mitra/warehouse/register';
  static const String mitraWarehouseEdit = '/mitra/warehouse/:id/edit';
  static const String mitraWarehouseHealth = '/mitra/warehouse/:id/health';
  static const String mitraProfile = '/mitra/profile';

  // ---------------------------------------------------------------------------
  // Admin Shell
  // ---------------------------------------------------------------------------
  static const String adminShell = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminWarehouses = '/admin/warehouses';
  static const String adminIncidents = '/admin/incidents';

  // ---------------------------------------------------------------------------
  // UMKM extra pages
  // ---------------------------------------------------------------------------
  static const String umkmNotifications = '/umkm/notifications';
  static const String umkmHelp = '/umkm/help';

  // ---------------------------------------------------------------------------
  // Mitra extra pages
  // ---------------------------------------------------------------------------
  static const String mitraNotifications = '/mitra/notifications';
  static const String mitraHelp = '/mitra/help';
  static const String mitraRevenueReport = '/mitra/revenue-report';

  // ---------------------------------------------------------------------------
  // Shared / Detail pages (no shell)
  // ---------------------------------------------------------------------------
  static const String warehouseDetail = '/warehouse/:id';

  // ---------------------------------------------------------------------------
  // Helper: build parameterised paths
  // ---------------------------------------------------------------------------

  /// Builds the monitoring route for a specific booking/warehouse ID.
  static String monitoringPath(String id) => '/umkm/monitoring/$id';

  /// Builds the warehouse edit route for a specific warehouse ID.
  static String warehouseEditPath(String id) => '/mitra/warehouse/$id/edit';

  /// Builds the warehouse health route for a specific warehouse ID.
  static String warehouseHealthPath(String id) =>
      '/mitra/warehouse/$id/health';

  /// Builds the warehouse detail route for a specific warehouse ID.
  static String warehouseDetailPath(String id) => '/warehouse/$id';
}
