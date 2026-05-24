import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/memory_cache.dart';
import '../../../../core/errors/failures.dart';
import '../../data/providers/booking_data_providers.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/usecases/calculate_cost_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/get_booking_history_usecase.dart';
import '../../domain/usecases/get_mitra_booking_history_usecase.dart';

// ---------------------------------------------------------------------------
// Booking State
// ---------------------------------------------------------------------------

/// State machine for the booking flow:
/// Idle → CalculatingCost → CostDisplayed → ProcessingPayment →
/// PaymentSuccess/PaymentFailed → BookingActive
enum BookingPhase {
  idle,
  calculatingCost,
  costDisplayed,
  processingPayment,
  paymentSuccess,
  paymentFailed,
  bookingActive,
}

class BookingState {
  final BookingPhase phase;
  final double? estimatedCost;
  final BookingEntity? activeBooking;
  final List<BookingEntity> history;
  final bool isLoadingHistory;
  final String? errorMessage;

  const BookingState({
    this.phase = BookingPhase.idle,
    this.estimatedCost,
    this.activeBooking,
    this.history = const [],
    this.isLoadingHistory = false,
    this.errorMessage,
  });

  BookingState copyWith({
    BookingPhase? phase,
    double? estimatedCost,
    BookingEntity? activeBooking,
    List<BookingEntity>? history,
    bool? isLoadingHistory,
    String? errorMessage,
  }) {
    return BookingState(
      phase: phase ?? this.phase,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      activeBooking: activeBooking ?? this.activeBooking,
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// BookingNotifier
// ---------------------------------------------------------------------------

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier(this._ref) : super(const BookingState());

  final Ref _ref;

  static const _cacheKeyHistory = 'booking_history';
  static const _cacheKeyMitraHistory = 'booking_history_mitra';

  MemoryCache get _cache => _ref.read(memoryCacheProvider);

  /// Calculates the estimated cost for a booking.
  ///
  /// Transitions: Idle → CalculatingCost → CostDisplayed (or error → Idle).
  void calculateCost({
    required double volumeM3,
    required double pricePerM3PerDay,
    required int durationDays,
  }) {
    state = state.copyWith(
      phase: BookingPhase.calculatingCost,
      errorMessage: null,
    );

    const useCase = CalculateCostUseCase();
    final result = useCase.call(CalculateCostParams(
      volumeM3: volumeM3,
      pricePerM3PerDay: pricePerM3PerDay,
      durationDays: durationDays,
    ));

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: BookingPhase.idle,
          errorMessage: failure.message,
        );
      },
      (cost) {
        state = state.copyWith(
          phase: BookingPhase.costDisplayed,
          estimatedCost: cost,
        );
      },
    );
  }

  /// Confirms the booking: processes payment then creates the booking.
  ///
  /// Transitions: CostDisplayed → ProcessingPayment →
  ///   PaymentSuccess → BookingActive (or PaymentFailed → Idle).
  Future<void> confirmBooking({
    required String umkmId,
    required String warehouseId,
    required String warehouseName,
    required double volumeM3,
    required double pricePerM3PerDay,
    required DateTime startDate,
    required int durationDays,
    required double remainingCapacity,
  }) async {
    state = state.copyWith(
      phase: BookingPhase.processingPayment,
      errorMessage: null,
    );

    final paymentService = _ref.read(paymentServiceProvider);
    final totalCost = volumeM3 * pricePerM3PerDay * durationDays;

    // Process payment.
    final paymentSuccess = await paymentService.processPayment(
      amount: totalCost,
      bookingId: '${warehouseId}_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!paymentSuccess) {
      state = state.copyWith(
        phase: BookingPhase.paymentFailed,
        errorMessage: 'Pembayaran gagal. Silakan coba lagi.',
      );
      return;
    }

    state = state.copyWith(phase: BookingPhase.paymentSuccess);

    // Create booking.
    final repository = _ref.read(bookingRepositoryProvider);
    final useCase = CreateBookingUseCase(repository);
    final result = await useCase.call(CreateBookingParams(
      umkmId: umkmId,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      volumeM3: volumeM3,
      pricePerM3PerDay: pricePerM3PerDay,
      startDate: startDate,
      durationDays: durationDays,
      remainingCapacity: remainingCapacity,
    ));

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: BookingPhase.paymentFailed,
          errorMessage: failure.message,
        );
      },
      (booking) {
        state = state.copyWith(
          phase: BookingPhase.bookingActive,
          activeBooking: booking,
        );
      },
    );
  }

  /// Fetches booking history for the given UMKM.
  Future<void> getHistory({required String umkmId}) async {
    state = state.copyWith(isLoadingHistory: true, errorMessage: null);

    final repository = _ref.read(bookingRepositoryProvider);
    final useCase = GetBookingHistoryUseCase(repository);
    final result = await useCase.call(
      GetBookingHistoryParams(umkmId: umkmId),
    );

    result.fold(
      (failure) {
        // On NoInternetFailure, return cached history if available.
        if (failure is NoInternetFailure) {
          final cached =
              _cache.get<List<BookingEntity>>(_cacheKeyHistory);
          if (cached != null) {
            state = state.copyWith(
              isLoadingHistory: false,
              history: cached,
            );
            return;
          }
        }
        state = state.copyWith(
          isLoadingHistory: false,
          errorMessage: failure.message,
        );
      },
      (bookings) {
        _cache.set<List<BookingEntity>>(_cacheKeyHistory, bookings);
        state = state.copyWith(
          isLoadingHistory: false,
          history: bookings,
        );
      },
    );
  }

  /// Fetches booking history for the given Mitra — bookings made AT any
  /// of the Mitra's warehouses.
  Future<void> getMitraHistory({required String mitraId}) async {
    state = state.copyWith(isLoadingHistory: true, errorMessage: null);

    final repository = _ref.read(bookingRepositoryProvider);
    final useCase = GetMitraBookingHistoryUseCase(repository);
    final result = await useCase.call(
      GetMitraBookingHistoryParams(mitraId: mitraId),
    );

    result.fold(
      (failure) {
        // On NoInternetFailure, return cached history if available.
        if (failure is NoInternetFailure) {
          final cached =
              _cache.get<List<BookingEntity>>(_cacheKeyMitraHistory);
          if (cached != null) {
            state = state.copyWith(
              isLoadingHistory: false,
              history: cached,
            );
            return;
          }
        }
        state = state.copyWith(
          isLoadingHistory: false,
          errorMessage: failure.message,
        );
      },
      (bookings) {
        _cache.set<List<BookingEntity>>(_cacheKeyMitraHistory, bookings);
        state = state.copyWith(
          isLoadingHistory: false,
          history: bookings,
        );
      },
    );
  }

  /// Resets the booking flow back to idle.
  void reset() {
    state = const BookingState();
  }

  /// Mitra scans UMKM QR to check-in (paid → active).
  Future<Either<Failure, BookingEntity>> checkIn({
    required String bookingId,
    required String qrCode,
  }) async {
    final repository = _ref.read(bookingRepositoryProvider);
    return repository.checkInBooking(bookingId: bookingId, qrCode: qrCode);
  }

  /// Mitra scans UMKM QR to check-out (active → completed).
  Future<Either<Failure, BookingEntity>> checkOut({
    required String bookingId,
    required String qrCode,
  }) async {
    final repository = _ref.read(bookingRepositoryProvider);
    return repository.checkOutBooking(bookingId: bookingId, qrCode: qrCode);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Canonical booking provider for the presentation layer.
final bookingProvider =
    StateNotifierProvider<BookingNotifier, BookingState>(
  (ref) => BookingNotifier(ref),
);
