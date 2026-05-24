import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/booking_provider.dart';

/// Mode scanner — check-in (paid → active) atau check-out (active → completed).
enum ScannerMode { checkIn, checkOut }

/// Halaman QR Scanner untuk Mitra.
///
/// Menggunakan [MobileScanner] untuk membaca QR dari layar UMKM. Setelah
/// QR terbaca, otomatis memanggil endpoint [checkIn] atau [checkOut] sesuai
/// [mode]. Pop dengan `true` saat sukses, `false` saat dibatalkan.
class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({
    super.key,
    required this.bookingId,
    required this.mode,
  });

  final String bookingId;
  final ScannerMode mode;

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => widget.mode == ScannerMode.checkIn
      ? 'Scan Check-In'
      : 'Scan Check-Out';

  String get _instruction => widget.mode == ScannerMode.checkIn
      ? 'Arahkan kamera ke QR Code dari UMKM\nuntuk konfirmasi barang masuk gudang'
      : 'Arahkan kamera ke QR Code dari UMKM\nuntuk konfirmasi barang diambil';

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });
    await _controller.stop();

    final notifier = ref.read(bookingProvider.notifier);
    final result = widget.mode == ScannerMode.checkIn
        ? await notifier.checkIn(bookingId: widget.bookingId, qrCode: code)
        : await notifier.checkOut(bookingId: widget.bookingId, qrCode: code);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _processing = false;
          _errorMessage = failure.message;
        });
        _controller.start();
      },
      (_) {
        _showSuccessAndPop();
      },
    );
  }

  Future<void> _showSuccessAndPop() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AppColors.success, size: 56),
        title: Text(
          widget.mode == ScannerMode.checkIn
              ? 'Check-In Berhasil!'
              : 'Check-Out Berhasil!',
        ),
        content: Text(
          widget.mode == ScannerMode.checkIn
              ? 'Barang telah masuk ke gudang. Booking sekarang aktif.'
              : 'Barang telah diambil. Booking sekarang selesai.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_title),
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scanner frame overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instruction & error
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Column(
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyRegular
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _instruction,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyRegular
                        .copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
