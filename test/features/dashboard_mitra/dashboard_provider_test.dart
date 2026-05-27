import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/dashboard_mitra/data/providers/dashboard_data_providers.dart';
import 'package:polarna/features/dashboard_mitra/presentation/providers/dashboard_provider.dart';

import 'fakes/fake_dashboard_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BookingEntity _sampleBooking({
  String id = 'b1',
  String warehouseName = 'Gudang A',
  PaymentStatus paymentStatus = PaymentStatus.paid,
}) {
  final now = DateTime(2025, 1, 15);
  return BookingEntity(
    id: id,
    umkmId: 'u1',
    warehouseId: 'w1',
    warehouseName: warehouseName,
    volumeM3: 5.0,
    startDate: now,
    endDate: now.add(const Duration(days: 30)),
    durationDays: 30,
    pricePerM3PerDay: 1000.0,
    totalCost: 150000.0,
    status: BookingStatus.active,
    paymentStatus: paymentStatus,
    qrCodeData: 'qr-data',
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// DashboardNotifier Tests
// ---------------------------------------------------------------------------

void main() {
  group('DashboardNotifier.exportCsv()', () {
    late FakeDashboardRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeDashboardRepository();
      container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('success → state.exportedCsv is set', () async {
      final bookings = [
        _sampleBooking(id: 'tx-1', warehouseName: 'Gudang Satu'),
      ];
      fakeRepo.getAllTransactionsResponses.add(Right(bookings));

      final notifier = container.read(dashboardNotifierProvider.notifier);

      await notifier.exportCsv('mitra-123');

      final state = container.read(dashboardNotifierProvider);
      expect(state.exportedCsv, isNotNull);
      expect(state.exportedCsv!, contains('ID Transaksi'));
      expect(state.exportedCsv!, contains('tx-1'));
      expect(state.isExporting, isFalse);
      expect(state.exportError, isNull);
    });

    test('failure → state.exportError is set', () async {
      fakeRepo.getAllTransactionsResponses
          .add(const Left(ServerFailure('Export failed')));

      final notifier = container.read(dashboardNotifierProvider.notifier);

      await notifier.exportCsv('mitra-123');

      final state = container.read(dashboardNotifierProvider);
      expect(state.exportError, isNotNull);
      expect(state.exportedCsv, isNull);
      expect(state.isExporting, isFalse);
    });

    test('exportCsv returns csv string on success', () async {
      final bookings = [
        _sampleBooking(id: 'tx-2', warehouseName: 'Gudang Dua'),
      ];
      fakeRepo.getAllTransactionsResponses.add(Right(bookings));

      final notifier = container.read(dashboardNotifierProvider.notifier);

      final result = await notifier.exportCsv('mitra-123');

      expect(result, isNotNull);
      expect(result!, contains('tx-2'));
    });

    test('exportCsv returns null on failure', () async {
      fakeRepo.getAllTransactionsResponses
          .add(const Left(ServerFailure('Oops')));

      final notifier = container.read(dashboardNotifierProvider.notifier);

      final result = await notifier.exportCsv('mitra-123');

      expect(result, isNull);
    });
  });
}
