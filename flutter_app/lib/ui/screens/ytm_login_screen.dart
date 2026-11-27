import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_provider.dart';
import '../widgets/lunarellys_logo.dart';
import '../widgets/subscreen_mini_player.dart';

class YouTubeMusicLoginScreen extends ConsumerStatefulWidget {
  final bool popOnComplete;

  const YouTubeMusicLoginScreen({
    super.key,
    this.popOnComplete = true,
  });

  @override
  ConsumerState<YouTubeMusicLoginScreen> createState() =>
      _YouTubeMusicLoginScreenState();
}

class _YouTubeMusicLoginScreenState
    extends ConsumerState<YouTubeMusicLoginScreen> {
  static const String _ytmLoginUrl =
      'https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fmusic.youtube.com%2F&hl=id&service=youtube&uilel=3';

  late final WebViewController _controller;
  double _progress = 0.08;
  bool _onYtmDomain = false;
  bool _completing = false;
  bool _completedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = (p / 100.0).clamp(0.0, 1.0));
          },
          onPageStarted: (url) {
            if (!mounted) return;
            final uri = Uri.tryParse(url);
            final isYtm = uri?.host.toLowerCase().contains('music.youtube.com') ?? false;
            if (isYtm != _onYtmDomain) {
              setState(() => _onYtmDomain = isYtm);
            }
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _progress = 1.0);
            final uri = Uri.tryParse(url);
            final isYtm = uri?.host.toLowerCase().contains('music.youtube.com') ?? false;
            if (isYtm) {
              setState(() => _onYtmDomain = true);
              await _inspectYtmSessionAndMaybeComplete();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_ytmLoginUrl));
  }

  Future<Map<String, dynamic>> _extractAccountMeta() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(r'''
        (function() {
          try {
            var loggedIn = false;
            var email = '';
            var name = '';
            var picture = '';
            var accountKey = '';
            if (window.ytcfg && typeof window.ytcfg.get === 'function') {
              loggedIn = !!window.ytcfg.get('LOGGED_IN');
              accountKey = String(window.ytcfg.get('DATASYNC_ID') || window.ytcfg.get('SESSION_INDEX') || '');
            }
            var avatarBtn = document.querySelector('ytmusic-settings-button img, button#avatar-btn img, a[href*="SignOut"] img');
            if (avatarBtn) {
              picture = avatarBtn.getAttribute('src') || '';
              if (avatarBtn.getAttribute('alt')) name = avatarBtn.getAttribute('alt') || '';
            }
            var activeSignIn = document.querySelector('a[href*="ServiceLogin"], ytmusic-nav-bar a.sign-in-link');
            if (!loggedIn && !activeSignIn && avatarBtn) {
              loggedIn = true;
            }
            return JSON.stringify({
              loggedIn: loggedIn,
              email: email,
              name: name,
              picture: picture,
              accountKey: accountKey
            });
          } catch (e) {
            return JSON.stringify({ loggedIn: false });
          }
        })();
      ''');

      var str = raw.toString().trim();
      if (str.startsWith('"') && str.endsWith('"')) {
        final first = jsonDecode(str);
        if (first is String) str = first;
      }
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {'loggedIn': false};
  }

  Future<void> _inspectYtmSessionAndMaybeComplete() async {
    if (_completedOnce || _completing) return;
    // Allow YouTube Music scripts brief moment to hydrate ytcfg after redirect
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || _completedOnce || _completing) return;

    final meta = await _extractAccountMeta();
    if (meta['loggedIn'] == true) {
      await _finalizeLogin(
        email: (meta['email'] ?? '').toString(),
        name: (meta['name'] ?? '').toString(),
        picture: (meta['picture'] ?? '').toString(),
        accountKey: (meta['accountKey'] ?? '').toString(),
      );
    }
  }

  Future<void> _finalizeLogin({
    String? email,
    String? name,
    String? picture,
    String? accountKey,
  }) async {
    if (_completing || _completedOnce) return;
    setState(() => _completing = true);
    _completedOnce = true;

    try {
      await ref.read(authProvider.notifier).completeYouTubeMusicLogin(
            email: email,
            name: name,
            picture: picture,
            accountKey: accountKey,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk dengan YouTube Music')),
      );
      if (widget.popOnComplete) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _manualConfirm() async {
    final meta = await _extractAccountMeta();
    await _finalizeLogin(
      email: (meta['email'] ?? '').toString(),
      name: (meta['name'] ?? '').toString(),
      picture: (meta['picture'] ?? '').toString(),
      accountKey: (meta['accountKey'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bg = AppColors.bgOf(context);
    final ink = AppColors.inkOf(context);
    final border = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: ink),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Row(
          children: [
            const YouTubeMusicLogoIcon(size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Masuk ke YouTube Music',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.35,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_onYtmDomain)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton(
                onPressed: _completing ? null : _manualConfirm,
                child: _completing
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Text(
                        'Selesai',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.iosBlue,
                        ),
                      ),
              ),
            ),
        ],
        bottom: _progress < 0.99
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.5),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2.5,
                  color: AppColors.ytRed,
                  backgroundColor: border.withAlpha(80),
                ),
              )
            : null,
      ),
      body: SubscreenMiniPlayerLayer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: ClipPath.shape(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(58),
            ),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: isDark ? const Color(0xFF141820) : Colors.white,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(58),
                  side: BorderSide(
                    color: border.withAlpha(isDark ? 95 : 150),
                    width: 0.9,
                  ),
                ),
              ),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
      ),
    );
  }
}
