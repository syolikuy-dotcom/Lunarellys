import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/device_permissions_service.dart';
import '../../state/dynamic_island_provider.dart';
import 'liquid_glass.dart';

void showPermissionsAndBackgroundSheet(BuildContext context, WidgetRef ref) {
  ref.read(devicePermissionsProvider.notifier).refresh();
  showLiquidGlassSheet<void>(
    context: context,
    builder: (ctx) => const _PermissionsSheetBody(),
  );
}

class _PermissionsSheetBody extends ConsumerStatefulWidget {
  const _PermissionsSheetBody();

  @override
  ConsumerState<_PermissionsSheetBody> createState() =>
      _PermissionsSheetBodyState();
}

class _PermissionsSheetBodyState extends ConsumerState<_PermissionsSheetBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(devicePermissionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(devicePermissionsProvider);
    final notifier = ref.read(devicePermissionsProvider.notifier);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IosSquircleBadge(
                icon: perms.backgroundReady
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.bell_fill,
                color: perms.backgroundReady
                    ? AppColors.iosGreen
                    : AppColors.iosOrange,
                size: 40,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perizinan & Latar Belakang',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    Text(
                      perms.backgroundReady
                          ? 'Dynamic Island & audio latar belakang siap 100%'
                          : 'Aktifkan izin agar Dynamic Island & musik tetap hidup saat layar mati',
                      style: TextStyle(fontSize: 12.5, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const IosSectionHeader(
            title: 'Izin Sistem & Audio Latar',
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          ),

          _PermissionCardTile(
            icon: CupertinoIcons.bell_fill,
            accent: AppColors.iosRed,
            title: 'Notifikasi & Lirik Lock Screen',
            subtitle:
                'Diperlukan untuk kontrol media, notifikasi lirik layar kunci, dan status unduhan.',
            granted: perms.notificationsGranted,
            actionLabel: perms.notificationsGranted ? 'Aktif' : 'Izinkan',
            onAction: () async {
              HapticFeedback.selectionClick();
              final ok = await notifier.requestNotifications();
              if (!ok && context.mounted) {
                await notifier.openNotificationSettings();
              } else if (ok) {
                ref.read(dynamicIslandEventProvider.notifier).show(
                      const DynamicIslandEvent(
                        icon: CupertinoIcons.bell_fill,
                        title: 'Notifikasi Diaktifkan',
                        subtitle: 'Dynamic Island & kontrol lockscreen siap',
                        accent: AppColors.iosGreen,
                      ),
                    );
              }
            },
          ),
          const SizedBox(height: 10),

          _PermissionCardTile(
            icon: CupertinoIcons.layers_alt_fill,
            accent: AppColors.iosBlue,
            title: 'Dynamic Island Luar Aplikasi',
            subtitle:
                'Membuat kapsul Dynamic Island tetap tampil mengambang saat keluar dari aplikasi.',
            granted: perms.overlayGranted,
            actionLabel: perms.overlayGranted ? 'Aktif' : 'Izinkan',
            onAction: () async {
              HapticFeedback.selectionClick();
              await notifier.requestOverlayPermission();
            },
          ),
          const SizedBox(height: 10),

          _PermissionCardTile(
            icon: CupertinoIcons.bolt_fill,
            accent: AppColors.iosGreen,
            title: 'Putar Tanpa Batas Baterai',
            subtitle:
                'Mencegah sistem menghentikan musik saat aplikasi berjalan di latar belakang.',
            granted: perms.batteryOptimizationIgnored,
            actionLabel:
                perms.batteryOptimizationIgnored ? 'Bebas Batas' : 'Aktifkan',
            onAction: () async {
              HapticFeedback.selectionClick();
              await notifier.requestBatteryOptimizationExemption();
            },
          ),
          const SizedBox(height: 10),

          _PermissionCardTile(
            icon: CupertinoIcons.bluetooth,
            accent: AppColors.iosIndigo,
            title: 'Perangkat Audio Bluetooth',
            subtitle:
                'Deteksi TWS, headset nirkabel, dan tombol jeda/lewati otomatis.',
            granted: perms.bluetoothGranted,
            actionLabel: perms.bluetoothGranted ? 'Tersedia' : 'Izinkan',
            onAction: () async {
              HapticFeedback.selectionClick();
              await notifier.requestBluetooth();
            },
          ),
          const SizedBox(height: 10),

          _PermissionCardTile(
            icon: CupertinoIcons.mic_fill,
            accent: AppColors.iosPink,
            title: 'Mikrofon (Kenali Musik)',
            subtitle:
                'Digunakan saat menggunakan fitur pengenalan suara lagu di sekitar.',
            granted: perms.microphoneGranted,
            actionLabel: perms.microphoneGranted ? 'Aktif' : 'Izinkan',
            onAction: () async {
              HapticFeedback.selectionClick();
              await notifier.requestMicrophone();
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    notifier.openNotificationSettings();
                  },
                  icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                  label: const Text('Setelan Notifikasi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    notifier.openAppSettings();
                  },
                  icon: const Icon(CupertinoIcons.gear_alt_fill, size: 18),
                  label: const Text('Info Aplikasi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionCardTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionCardTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);

    return LiquidGlassCard(
      radius: 22,
      chromaticAccent: granted ? AppColors.iosGreen : accent,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          IosSquircleBadge(icon: icon, color: accent, size: 38, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.3, color: sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          LiquidGlassTap(
            onTap: onAction,
            pressedScale: 0.94,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.success.withAlpha(isDark ? 48 : 28)
                    : (isDark ? Colors.white : const Color(0xFF111315)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: granted
                      ? AppColors.success
                      : (isDark ? Colors.black : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
