import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../widgets/lunarellys_logo.dart';

class AuthScreen extends ConsumerWidget {
  final bool allowBack;

  const AuthScreen({super.key, this.allowBack = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isDark = AppColors.isDark(context);
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final card = isDark ? AppColors.darkSurface : const Color(0xFFF7F8FA);
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    final border = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: allowBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 42).clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        SizedBox(height: allowBack ? 6 : 22),
                        const LunarellysHorizonLogo(size: 88),
                        const SizedBox(height: 8),
                        Text(
                          'Lunarellys',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: sub,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Musikmu, caramu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Masuk untuk membawa pustaka YouTube Music-mu, atau langsung mulai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: sub,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: border, width: 1),
                          ),
                          child: Column(
                            children: [
                              _featureRow(
                                context,
                                icon: Icons.sync_rounded,
                                title: 'Sinkron dengan YouTube Music',
                                subtitle: 'Lagu disukai, playlist, dan pustaka ikut terbawa',
                              ),
                              Divider(height: 1, indent: 62, endIndent: 16, color: border),
                              _featureRow(
                                context,
                                icon: Icons.group_outlined,
                                title: 'Dengar bersama',
                                subtitle: 'Satu ruangan, satu lagu, secara langsung',
                              ),
                              Divider(height: 1, indent: 62, endIndent: 16, color: border),
                              _featureRow(
                                context,
                                icon: Icons.palette_outlined,
                                title: 'Dua tampilan',
                                subtitle: 'Datar atau Kaca, ganti kapan saja',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Column(
                      children: [
                        if (auth.error != null) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(24),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.error.withAlpha(80)),
                            ),
                            child: Text(
                              auth.error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : const Color(0xFF111315),
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: auth.isAuthenticating
                                ? null
                                : () async {
                                    final res = await ref
                                        .read(authProvider.notifier)
                                        .signInWithGoogle();
                                    if (!context.mounted) return;
                                    if (!res.launched && res.message != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message!)),
                                      );
                                    } else if (res.launched && allowBack) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            icon: auth.isAuthenticating
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded, size: 20),
                            label: Text(
                              auth.isAuthenticating
                                  ? 'Membuka halaman masuk...'
                                  : 'Masuk dengan YouTube Music',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceMuted
                                  : const Color(0xFFEFF1F4),
                              foregroundColor: ink,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: auth.isAuthenticating
                                ? null
                                : () async {
                                    await ref
                                        .read(authProvider.notifier)
                                        .continueAsGuest();
                                    if (context.mounted && allowBack) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: const Text(
                              'Lanjutkan tanpa akun',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Kamu bisa masuk kapan saja lewat Pengaturan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: sub),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _featureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final ink = AppColors.inkOf(context);
    final sub = AppColors.subOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ink.withAlpha(14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: ink),
          ),
          const SizedBox(width: 14),
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
                  style: TextStyle(
                    fontSize: 12.5,
                    color: sub,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
