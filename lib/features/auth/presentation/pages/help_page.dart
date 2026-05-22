import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

/// Static help/FAQ page with expandable questions.
///
/// Displays common questions and answers using [ExpansionTile]. The FAQ
/// list is selected based on the current user's [UserRole] — UMKM users
/// see tenant-focused questions, Mitra users see warehouse-owner questions.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  // ---------------------------------------------------------------------------
  // FAQ content
  // ---------------------------------------------------------------------------

  static const List<({String question, String answer})> _umkmFaqs = [
    (
      question: 'Bagaimana cara memesan gudang?',
      answer:
          'Buka tab Cari, pilih gudang yang sesuai, tap Pesan Sekarang, '
          'isi form pemesanan, dan konfirmasi.',
    ),
    (
      question: 'Bagaimana cara memantau suhu?',
      answer:
          'Buka tab Transaksi, tap booking aktif, lalu tap Pantau Suhu '
          'untuk melihat data real-time dari sensor.',
    ),
    (
      question: 'Bagaimana cara menghubungi support?',
      answer: 'Email: support@polarna.id\nWhatsApp: +62 822-8451-9884',
    ),
    (
      question: 'Apa itu IoT Sensor?',
      answer:
          'IoT Sensor adalah perangkat ESP32 + DHT22 yang dipasang di gudang '
          'untuk memantau suhu dan kelembapan secara real-time. Data dikirim '
          'setiap 7 detik ke aplikasi.',
    ),
  ];

  static const List<({String question, String answer})> _mitraFaqs = [
    (
      question: 'Bagaimana cara mendaftarkan gudang?',
      answer:
          'Buka tab Gudang, tap tombol +, isi form registrasi gudang lengkap '
          'dengan nama, alamat, lokasi GPS (pilih di peta), kapasitas, harga, '
          'kategori suhu (Frozen/Chilled), dan upload foto.',
    ),
    (
      question: 'Bagaimana cara mengaktifkan/menonaktifkan gudang?',
      answer:
          'Di tab Gudang, setiap kartu gudang ada toggle. Aktifkan untuk '
          'menerima pesanan UMKM, nonaktifkan saat maintenance.',
    ),
    (
      question: 'Bagaimana cara melihat pendapatan?',
      answer:
          'Buka tab Beranda, lihat ringkasan pendapatan harian dan bulanan, '
          'atau buka menu Laporan Pendapatan untuk detail.',
    ),
    (
      question: 'Bagaimana cara menghubungkan IoT Sensor?',
      answer:
          'Pasang ESP32 + sensor DHT22 di gudang, upload firmware dengan '
          'warehouse ID dari Firestore. Sensor akan mengirim data suhu '
          'setiap 7 detik.',
    ),
    (
      question: 'Bagaimana cara menghubungi support?',
      answer: 'Email: support@polarna.id | WhatsApp: +62 812-3456-7890',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final role = ref.watch(authProvider).valueOrNull?.role;
    final faqs = role == UserRole.mitra ? _mitraFaqs : _umkmFaqs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bantuan'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Header
          AppCard(
            child: Row(
              children: [
                AppRoundIconAvatar(
                  icon: Icons.support_agent,
                  size: 48,
                  backgroundColor: AppColors.infoSoft,
                  iconColor: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Bantuan',
                        style: AppTextStyles.heading3.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Temukan jawaban untuk pertanyaan umum di bawah ini.',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // FAQ list
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FaqTile(
                    question: faqs[i].question,
                    answer: faqs[i].answer,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Contact section
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masih butuh bantuan?',
                  style: AppTextStyles.heading3.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Hubungi tim support kami:',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'support@polarna.id',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '+62 822-8451-9884',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      childrenPadding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      title: Text(
        question,
        style: AppTextStyles.bodyRegular.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
