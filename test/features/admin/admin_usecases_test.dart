import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/admin/domain/entities/platform_summary.dart';
import 'package:polarna/features/admin/domain/usecases/get_platform_summary_usecase.dart';
import 'package:polarna/features/admin/domain/usecases/manage_users_usecase.dart';

import 'fakes/fake_admin_repository.dart';

void main() {
  late FakeAdminRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAdminRepository();
  });

  // -------------------------------------------------------------------------
  // ActivateUserUseCase
  // -------------------------------------------------------------------------

  group('ActivateUserUseCase', () {
    late ActivateUserUseCase useCase;

    setUp(() {
      useCase = ActivateUserUseCase(fakeRepo);
    });

    test('delegates userId to repository and returns Right(unit) on success',
        () async {
      fakeRepo.activateUserResponses.add(const Right(unit));

      final result = await useCase(
        const ManageUserParams(userId: 'user-123'),
      );

      expect(result, const Right(unit));
      expect(fakeRepo.activateUserCalls.length, 1);
      expect(fakeRepo.activateUserCalls.first.userId, 'user-123');
    });

    test('returns Left(Failure) when repository fails', () async {
      fakeRepo.activateUserResponses
          .add(const Left(ServerFailure('Activation failed')));

      final result = await useCase(
        const ManageUserParams(userId: 'user-456'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'Activation failed'),
        (_) => fail('Expected Left'),
      );
      expect(fakeRepo.activateUserCalls.first.userId, 'user-456');
    });
  });

  // -------------------------------------------------------------------------
  // DeactivateUserUseCase
  // -------------------------------------------------------------------------

  group('DeactivateUserUseCase', () {
    late DeactivateUserUseCase useCase;

    setUp(() {
      useCase = DeactivateUserUseCase(fakeRepo);
    });

    test('delegates userId to repository and returns Right(unit) on success',
        () async {
      fakeRepo.deactivateUserResponses.add(const Right(unit));

      final result = await useCase(
        const ManageUserParams(userId: 'mitra-001'),
      );

      expect(result, const Right(unit));
      expect(fakeRepo.deactivateUserCalls.length, 1);
      expect(fakeRepo.deactivateUserCalls.first.userId, 'mitra-001');
    });

    test('returns Left(Failure) when repository fails', () async {
      fakeRepo.deactivateUserResponses
          .add(const Left(ServerFailure('Deactivation failed')));

      final result = await useCase(
        const ManageUserParams(userId: 'mitra-002'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'Deactivation failed'),
        (_) => fail('Expected Left'),
      );
      expect(fakeRepo.deactivateUserCalls.first.userId, 'mitra-002');
    });
  });

  // -------------------------------------------------------------------------
  // GetPlatformSummaryUseCase
  // -------------------------------------------------------------------------

  group('GetPlatformSummaryUseCase', () {
    late GetPlatformSummaryUseCase useCase;

    setUp(() {
      useCase = GetPlatformSummaryUseCase(fakeRepo);
    });

    test('returns Right(PlatformSummary) on success', () async {
      const summary = PlatformSummary(
        totalUsers: 100,
        activeWarehouses: 25,
        activeTransactions: 50,
        grossMerchandiseValue: 5000000.0,
      );
      fakeRepo.getPlatformSummaryResponses.add(const Right(summary));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (s) {
          expect(s.totalUsers, 100);
          expect(s.activeWarehouses, 25);
          expect(s.activeTransactions, 50);
          expect(s.totalRevenue, 5000000.0);
        },
      );
      expect(fakeRepo.getPlatformSummaryCallCount, 1);
    });

    test('returns Left(Failure) when repository fails', () async {
      fakeRepo.getPlatformSummaryResponses
          .add(const Left(ServerFailure('Summary unavailable')));

      final result = await useCase();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'Summary unavailable'),
        (_) => fail('Expected Left'),
      );
    });
  });
}
