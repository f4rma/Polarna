import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/dashboard_mitra/domain/entities/revenue_summary.dart';
import 'package:polarna/features/dashboard_mitra/domain/usecases/export_transactions_csv_usecase.dart';
import 'package:polarna/features/dashboard_mitra/domain/usecases/get_revenue_usecase.dart';

import 'fakes/fake_dashboard_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RevenueSummary _sampleSummary() {
  return const RevenueSummary(
    dailyRevenue: 500000.0,
    monthlyRevenue: 15000000.0,
    activeTransactions: 3,
    utilizationPercent: 72.5,
    monthlyRevenueHistory: [
      1000000,
      1200000,
      1100000,
      1300000,
      1400000,
      1500000,
      1600000,
      1700000,
      1800000,
      1900000,
      2000000,
      1500000,
    ],
  );
}

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
// GetRevenueUseCase Tests
// ---------------------------------------------------------------------------

void main() {
  group('GetRevenueUseCase', () {
    late FakeDashboardRepository fakeRepo;
    late GetRevenueUseCase useCase;

    setUp(() {
      fakeRepo = FakeDashboardRepository();
      useCase = GetRevenueUseCase(fakeRepo);
    });

    test('delegates mitraId to repository', () async {
      final summary = _sampleSummary();
      fakeRepo.getRevenueSummaryResponses.add(Right(summary));

      await useCase.call(const GetRevenueParams(mitraId: 'mitra-123'));

      expect(fakeRepo.getRevenueSummaryCalls.length, 1);
      expect(fakeRepo.getRevenueSummaryCalls.first.mitraId, 'mitra-123');
    });

    test('returns Right(RevenueSummary) on success', () async {
      final summary = _sampleSummary();
      fakeRepo.getRevenueSummaryResponses.add(Right(summary));

      final result =
          await useCase.call(const GetRevenueParams(mitraId: 'mitra-123'));

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (s) => expect(s, equals(summary)),
      );
    });

    test('returns Left(Failure) on failure', () async {
      fakeRepo.getRevenueSummaryResponses
          .add(const Left(ServerFailure('Server error')));

      final result =
          await useCase.call(const GetRevenueParams(mitraId: 'mitra-123'));

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // ExportTransactionsCsvUseCase Tests
  // -------------------------------------------------------------------------

  group('ExportTransactionsCsvUseCase', () {
    late FakeDashboardRepository fakeRepo;
    late ExportTransactionsCsvUseCase useCase;

    setUp(() {
      fakeRepo = FakeDashboardRepository();
      useCase = ExportTransactionsCsvUseCase(fakeRepo);
    });

    test('fetches transactions and produces CSV string', () async {
      final bookings = [
        _sampleBooking(id: 'tx-1', warehouseName: 'Gudang Satu'),
        _sampleBooking(id: 'tx-2', warehouseName: 'Gudang Dua'),
      ];
      fakeRepo.getAllTransactionsResponses.add(Right(bookings));

      final result = await useCase.call(
        const ExportTransactionsCsvParams(mitraId: 'mitra-123'),
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (csv) {
          // CSV should contain headers
          expect(csv, contains('ID Transaksi'));
          expect(csv, contains('Nama UMKM'));
          expect(csv, contains('Volume'));
          expect(csv, contains('Total Biaya'));
          expect(csv, contains('Status Pembayaran'));
          // CSV should contain data rows
          expect(csv, contains('tx-1'));
          expect(csv, contains('tx-2'));
          expect(csv, contains('Gudang Satu'));
          expect(csv, contains('Gudang Dua'));
        },
      );
    });

    test('failure from repository is propagated', () async {
      fakeRepo.getAllTransactionsResponses
          .add(const Left(ServerFailure('DB error')));

      final result = await useCase.call(
        const ExportTransactionsCsvParams(mitraId: 'mitra-123'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('empty transaction list → CSV with headers only', () async {
      fakeRepo.getAllTransactionsResponses.add(const Right([]));

      final result = await useCase.call(
        const ExportTransactionsCsvParams(mitraId: 'mitra-123'),
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (csv) {
          // Should contain headers
          expect(csv, contains('ID Transaksi'));
          expect(csv, contains('Nama UMKM'));
          // Should NOT contain any data rows (only the header line)
          final lines = csv.trim().split('\n');
          expect(lines.length, 1);
        },
      );
    });

    test('delegates mitraId, from, to params to repository', () async {
      fakeRepo.getAllTransactionsResponses.add(const Right([]));
      final from = DateTime(2025, 1, 1);
      final to = DateTime(2025, 1, 31);

      await useCase.call(
        ExportTransactionsCsvParams(mitraId: 'mitra-456', from: from, to: to),
      );

      expect(fakeRepo.getAllTransactionsCalls.length, 1);
      final call = fakeRepo.getAllTransactionsCalls.first;
      expect(call.mitraId, 'mitra-456');
      expect(call.from, from);
      expect(call.to, to);
    });
  });
}
