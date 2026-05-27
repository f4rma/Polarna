import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/admin/data/providers/admin_data_providers.dart';
import 'package:polarna/features/admin/domain/entities/platform_summary.dart';
import 'package:polarna/features/admin/presentation/providers/admin_provider.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';

import 'fakes/fake_admin_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserEntity _sampleUser({
  String uid = 'u1',
  String email = 'user@test.com',
  UserRole role = UserRole.umkm,
  bool isActive = true,
}) {
  return UserEntity(
    uid: uid,
    email: email,
    fullName: 'Test User',
    phoneNumber: '08123456789',
    role: role,
    isEmailVerified: true,
    isActive: isActive,
    createdAt: DateTime(2025, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// AdminNotifier Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAdminRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeAdminRepository();
    container = ProviderContainer(
      overrides: [
        adminRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // -------------------------------------------------------------------------
  // loadSummary()
  // -------------------------------------------------------------------------

  group('AdminNotifier.loadSummary()', () {
    test('success → state.summary is set', () async {
      const summary = PlatformSummary(
        totalUsers: 50,
        activeWarehouses: 10,
        activeTransactions: 20,
        grossMerchandiseValue: 1000000.0,
      );
      fakeRepo.getPlatformSummaryResponses.add(const Right(summary));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.loadSummary();

      final state = container.read(adminNotifierProvider);
      expect(state.summary, summary);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('failure → state.errorMessage is set', () async {
      fakeRepo.getPlatformSummaryResponses
          .add(const Left(ServerFailure('Server error')));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.loadSummary();

      final state = container.read(adminNotifierProvider);
      expect(state.summary, isNull);
      expect(state.errorMessage, 'Server error');
      expect(state.isLoading, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // loadUsers()
  // -------------------------------------------------------------------------

  group('AdminNotifier.loadUsers()', () {
    test('success → state.users populated', () async {
      final users = [
        _sampleUser(uid: 'u1', role: UserRole.umkm),
        _sampleUser(uid: 'u2', role: UserRole.mitra),
      ];
      fakeRepo.getAllUsersResponses.add(Right(users));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.loadUsers();

      final state = container.read(adminNotifierProvider);
      expect(state.users.length, 2);
      expect(state.users[0].uid, 'u1');
      expect(state.users[1].uid, 'u2');
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('failure → state.errorMessage is set', () async {
      fakeRepo.getAllUsersResponses
          .add(const Left(ServerFailure('Failed to load users')));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.loadUsers();

      final state = container.read(adminNotifierProvider);
      expect(state.users, isEmpty);
      expect(state.errorMessage, 'Failed to load users');
      expect(state.isLoading, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // activateUser()
  // -------------------------------------------------------------------------

  group('AdminNotifier.activateUser()', () {
    test('calls repo and reloads users on success', () async {
      // Queue: activateUser succeeds, then loadUsers succeeds.
      fakeRepo.activateUserResponses.add(const Right(unit));
      fakeRepo.getAllUsersResponses.add(Right([
        _sampleUser(uid: 'u1', isActive: true),
      ]));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.activateUser('u1');
      // The fold success branch fires loadUsers asynchronously; allow it to
      // settle.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(adminNotifierProvider);
      // Verify repo was called with correct userId.
      expect(fakeRepo.activateUserCalls.length, 1);
      expect(fakeRepo.activateUserCalls.first.userId, 'u1');
      // Verify users were reloaded.
      expect(fakeRepo.getAllUsersCallCount, 1);
      expect(state.users.length, 1);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('failure → state.errorMessage is set, users not reloaded', () async {
      fakeRepo.activateUserResponses
          .add(const Left(ServerFailure('Activation failed')));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.activateUser('u1');

      final state = container.read(adminNotifierProvider);
      expect(state.errorMessage, 'Activation failed');
      expect(state.isLoading, isFalse);
      // loadUsers should NOT have been called.
      expect(fakeRepo.getAllUsersCallCount, 0);
    });
  });

  // -------------------------------------------------------------------------
  // deactivateUser()
  // -------------------------------------------------------------------------

  group('AdminNotifier.deactivateUser()', () {
    test('calls repo and reloads users on success', () async {
      // Queue: deactivateUser succeeds, then loadUsers succeeds.
      fakeRepo.deactivateUserResponses.add(const Right(unit));
      fakeRepo.getAllUsersResponses.add(Right([
        _sampleUser(uid: 'u1', isActive: false),
      ]));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.deactivateUser('u1');
      // The fold success branch fires loadUsers asynchronously; allow it to
      // settle.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(adminNotifierProvider);
      // Verify repo was called with correct userId.
      expect(fakeRepo.deactivateUserCalls.length, 1);
      expect(fakeRepo.deactivateUserCalls.first.userId, 'u1');
      // Verify users were reloaded.
      expect(fakeRepo.getAllUsersCallCount, 1);
      expect(state.users.length, 1);
      expect(state.users.first.isActive, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('failure → state.errorMessage is set, users not reloaded', () async {
      fakeRepo.deactivateUserResponses
          .add(const Left(ServerFailure('Deactivation failed')));

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.deactivateUser('u1');

      final state = container.read(adminNotifierProvider);
      expect(state.errorMessage, 'Deactivation failed');
      expect(state.isLoading, isFalse);
      // loadUsers should NOT have been called.
      expect(fakeRepo.getAllUsersCallCount, 0);
    });
  });
}
