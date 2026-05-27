// Hand-rolled fake for [AdminRepository] used by AdminNotifier and use-case
// unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly instead of
// silently degrading.

import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/admin/domain/entities/platform_summary.dart';
import 'package:polarna/features/admin/domain/repositories/admin_repository.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';

/// Captured arguments of a single `activateUser` call.
class ActivateUserCall {
  final String userId;
  const ActivateUserCall(this.userId);
}

/// Captured arguments of a single `deactivateUser` call.
class DeactivateUserCall {
  final String userId;
  const DeactivateUserCall(this.userId);
}

class FakeAdminRepository implements AdminRepository {
  // ---------------------------------------------------------------------------
  // Response queues — tests enqueue responses in the order they expect them.
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, Unit>> activateUserResponses = Queue();
  final Queue<Either<Failure, Unit>> deactivateUserResponses = Queue();
  final Queue<Either<Failure, PlatformSummary>> getPlatformSummaryResponses =
      Queue();
  final Queue<Either<Failure, List<UserEntity>>> getAllUsersResponses = Queue();

  // ---------------------------------------------------------------------------
  // Invocation log — tests assert on call counts and arguments.
  // ---------------------------------------------------------------------------

  final List<ActivateUserCall> activateUserCalls = [];
  final List<DeactivateUserCall> deactivateUserCalls = [];
  int getPlatformSummaryCallCount = 0;
  int getAllUsersCallCount = 0;

  // ---------------------------------------------------------------------------
  // Repository API.
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Unit>> activateUser(String userId) async {
    activateUserCalls.add(ActivateUserCall(userId));
    if (activateUserResponses.isEmpty) {
      throw StateError(
          'No activateUserResponses queued for activateUser($userId)');
    }
    return activateUserResponses.removeFirst();
  }

  @override
  Future<Either<Failure, Unit>> deactivateUser(String userId) async {
    deactivateUserCalls.add(DeactivateUserCall(userId));
    if (deactivateUserResponses.isEmpty) {
      throw StateError(
          'No deactivateUserResponses queued for deactivateUser($userId)');
    }
    return deactivateUserResponses.removeFirst();
  }

  @override
  Future<Either<Failure, PlatformSummary>> getPlatformSummary() async {
    getPlatformSummaryCallCount += 1;
    if (getPlatformSummaryResponses.isEmpty) {
      throw StateError('No getPlatformSummaryResponses queued');
    }
    return getPlatformSummaryResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers() async {
    getAllUsersCallCount += 1;
    if (getAllUsersResponses.isEmpty) {
      throw StateError('No getAllUsersResponses queued');
    }
    return getAllUsersResponses.removeFirst();
  }
}
