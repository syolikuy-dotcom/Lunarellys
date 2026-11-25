import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/music_models.dart';
import 'settings_provider.dart';

class GoogleSignInLaunchResult {
  final bool launched;
  final bool oauthUnconfigured;
  final String? message;

  const GoogleSignInLaunchResult({
    this.launched = false,
    this.oauthUnconfigured = false,
    this.message,
  });
}

class AuthState {
  final AuthUser? user;
  final String? sessionToken;
  final bool onboardingCompleted;
  final bool isAuthenticating;
  final bool isSyncing;
  final String? lastSyncAt;
  final String? error;

  const AuthState({
    this.user,
    this.sessionToken,
    this.onboardingCompleted = false,
    this.isAuthenticating = false,
    this.isSyncing = false,
    this.lastSyncAt,
    this.error,
  });

  bool get isSignedInGoogle =>
      user != null && !user!.isGuest && sessionToken != null && sessionToken!.isNotEmpty;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    String? sessionToken,
    bool clearToken = false,
    bool? onboardingCompleted,
    bool? isAuthenticating,
    bool? isSyncing,
    String? lastSyncAt,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      sessionToken: clearToken ? null : (sessionToken ?? this.sessionToken),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPreferences _prefs;
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  AuthNotifier(this._prefs, this._ref) : super(const AuthState()) {
    _load();
    _initDeepLinks();
  }

  void _load() {
    final token = _prefs.getString('auth_session_token');
    final rawUser = _prefs.getString('auth_user_json');
    final done = _prefs.getBool('auth_onboarding_done') ?? false;
    final lastSync = _prefs.getString('auth_last_sync_at');

    AuthUser? savedUser;
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) {
          savedUser = AuthUser.fromJson(decoded);
        }
      } catch (_) {}
    }

    state = AuthState(
      user: savedUser,
      sessionToken: token,
      onboardingCompleted: done,
      lastSyncAt: lastSync,
    );

    if (token != null && token.isNotEmpty) {
      unawaited(_refreshProfile(token));
    }
  }

  void _initDeepLinks() {
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    }).catchError((_) {});

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    }, onError: (_) {});
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (uri.scheme != 'lunarellys' || uri.host != 'auth') return;

    final err = uri.queryParameters['error'];
    if (err != null && err.isNotEmpty) {
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Google sign-in was cancelled or could not be completed.',
      );
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;

    final fallbackUser = AuthUser(
      id: 'google_pending',
      name: uri.queryParameters['name'] ?? 'Google Listener',
      email: uri.queryParameters['email'] ?? '',
      picture: uri.queryParameters['picture'] ?? '',
      isGuest: false,
    );

    await _persistSession(user: fallbackUser, token: token);
    state = state.copyWith(
      user: fallbackUser,
      sessionToken: token,
      onboardingCompleted: true,
      isAuthenticating: false,
      clearError: true,
    );

    await _refreshProfile(token);
  }

  Future<void> _refreshProfile(String token) async {
    try {
      final api = _ref.read(apiClientProvider);
      final user = await api.getCurrentUser(token);
      if (user.id.isNotEmpty) {
        await _persistSession(user: user, token: token);
        state = state.copyWith(user: user, sessionToken: token);
      }
    } catch (_) {}
  }

  Future<void> _persistSession({required AuthUser user, String? token}) async {
    await _prefs.setString('auth_user_json', jsonEncode(user.toJson()));
    await _prefs.setBool('auth_onboarding_done', true);
    if (token != null) {
      await _prefs.setString('auth_session_token', token);
    } else {
      await _prefs.remove('auth_session_token');
    }
  }

  Future<GoogleSignInLaunchResult> signInWithGoogle() async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    final api = _ref.read(apiClientProvider);
    try {
      final status = await api.getAuthStatus();
      if (!status.googleOAuthConfigured) {
        state = state.copyWith(isAuthenticating: false);
        return const GoogleSignInLaunchResult(
          launched: false,
          oauthUnconfigured: true,
          message: 'Google Sign-In is currently unavailable. Please continue as Guest for now.',
        );
      }

      final url = Uri.parse(api.buildGoogleLoginUrl());
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        state = state.copyWith(
          isAuthenticating: false,
          error: 'Could not open browser for Google sign-in.',
        );
        return const GoogleSignInLaunchResult(
          launched: false,
          message: 'Could not open browser for Google sign-in.',
        );
      }

      state = state.copyWith(isAuthenticating: false);
      return const GoogleSignInLaunchResult(launched: true);
    } catch (_) {
      state = state.copyWith(
        isAuthenticating: false,
        error: 'Sign-in is temporarily unavailable. Check your connection or continue as Guest.',
      );
      return const GoogleSignInLaunchResult(
        launched: false,
        message: 'Sign-in is temporarily unavailable. Check your connection or continue as Guest.',
      );
    }
  }

  Future<void> continueAsGuest() async {
    const guest = AuthUser(
      id: 'guest',
      name: 'Guest Listener',
      email: 'Local Device Profile',
      isGuest: true,
    );
    await _persistSession(user: guest, token: null);
    state = state.copyWith(
      user: guest,
      clearToken: true,
      onboardingCompleted: true,
      isAuthenticating: false,
      clearError: true,
    );
  }

  Future<void> signOut() async {
    await _prefs.remove('auth_session_token');
    await _prefs.remove('auth_user_json');
    await _prefs.setBool('auth_onboarding_done', false);
    state = const AuthState(onboardingCompleted: false);
  }

  void setSyncStatus({required bool syncing, String? lastSyncAt}) {
    if (lastSyncAt != null) {
      _prefs.setString('auth_last_sync_at', lastSyncAt);
    }
    state = state.copyWith(isSyncing: syncing, lastSyncAt: lastSyncAt);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(sharedPreferencesProvider), ref);
});
