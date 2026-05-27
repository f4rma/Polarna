// Hand-rolled fake for [DashboardRepository] used by dashboard use-case
// and provider unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly.

import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/dashboard_mitra/domain/entities/revenue_summary.dart';
import 'package:polarna/features/dashboard_mitra/domain/repositories/dashboard_repository.dart';

/// Captured arguments of a single `getRevenueSummary` call.
class GetRevenueSummaryCall {
  final String mitraId;
  const GetRevenueSummaryCall(this.mitraId);
}

/// Captured arguments of a single `getActiveTransactions` call.
class GetActiveTransactionsCall {
  final String mitraId;
  const GetActiveTransactionsCall(this.mitraId);
}

/// Captured arguments of a single `getAllTransactions` call.
class GetAllTransactionsCall {
  final String mitraId;
  final DateTime? from;
  final DateTime? to;
  const GetAllTransactionsCall(this.mitraId, {this.from, this.to});
}

class FakeDashboardRepository implements DashboardRepository {
  // ---------------------------------------------------------------------------
  // Response queues
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, RevenueSummary>> getRevenueSummaryResponses =
      Queue();
  final Queue<Either<Failure, List<BookingEntity>>>
      getActiveTransactionsResponses = Queue();
  final Queue<Either<Failure, List<BookingEntity>>>
      getAllTransactionsResponses = Queue();

  // ---------------------------------------------------------------------------
  // Invocation log
  // ---------------------------------------------------------------------------

  final List<GetRevenueSummaryCall> getRevenueSummaryCalls = [];
  final List<GetActiveTransactionsCall> getActiveTransactionsCalls = [];
  final List<GetAllTransactionsCall> getAllTransactionsCalls = [];

  // ---------------------------------------------------------------------------
  // Repository API
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, RevenueSummary>> getRevenueSummary(
    String mitraId,
  ) async {
    getRevenueSummaryCalls.add(GetRevenueSummaryCall(mitraId));
    if (getRevenueSummaryResponses.isEmpty) {
      throw StateError(
        'No getRevenueSummaryResponses queued for getRevenueSummary($mitraId)',
      );
    }
    return getRevenueSummaryResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getActiveTransactions(
    String mitraId,
  ) async {
    getActiveTransactionsCalls.add(GetActiveTransactionsCall(mitraId));
    if (getActiveTransactionsResponses.isEmpty) {
      throw StateError(
        'No getActiveTransactionsResponses queued for getActiveTransactions($mitraId)',
      );
    }
    return getActiveTransactionsResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getAllTransactions({
    required String mitraId,
    DateTime? from,
    DateTime? to,
  }) async {
    getAllTransactionsCalls
        .add(GetAllTransactionsCall(mitraId, from: from, to: to));
    if (getAllTransactionsResponses.isEmpty) {
      throw StateError(
        'No getAllTransactionsResponses queued for getAllTransactions($mitraId)',
      );
    }
    return getAllTransactionsResponses.removeFirst();
  }
}
