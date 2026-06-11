import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/hive_helper.dart';

enum RingAuthProvider { google, kakao, naver, line, yahoo, facebook, email }

class DeviceAccountLinkRequiredException implements Exception {
  const DeviceAccountLinkRequiredException({
    this.canonicalAccountId,
    this.providerLinkedToDifferentAccount = false,
  });

  final String? canonicalAccountId;
  final bool providerLinkedToDifferentAccount;

  @override
  String toString() =>
      'DeviceAccountLinkRequiredException(canonicalAccountId: $canonicalAccountId)';
}

class ProviderAccountConflictException implements Exception {
  const ProviderAccountConflictException();

  @override
  String toString() => 'ProviderAccountConflictException';
}

class SignInProviderRequiredException implements Exception {
  const SignInProviderRequiredException();

  @override
  String toString() => 'SignInProviderRequiredException';
}

class AuthSessionInfo {
  const AuthSessionInfo({
    required this.canonicalAccountId,
    required this.anonUserId,
    required this.deviceId,
    this.deviceTransferRequired = false,
    this.previousDeviceLabel,
  });

  final String canonicalAccountId;
  final String anonUserId;
  final String deviceId;
  final bool deviceTransferRequired;
  final String? previousDeviceLabel;

  factory AuthSessionInfo.fromJson(
    Map<String, dynamic> json, {
    required String deviceId,
    required String fallbackUid,
  }) {
    final activeDevice =
        json['activeDevice'] is Map
            ? Map<String, dynamic>.from(json['activeDevice'] as Map)
            : const <String, dynamic>{};
    final activeDeviceStatus = activeDevice['status']?.toString();
    final previousDeviceLabel =
        activeDevice['previousPlatform']?.toString().trim().isNotEmpty == true
            ? activeDevice['previousPlatform'].toString()
            : activeDevice['platform']?.toString();
    final canonical =
        json['canonicalAccountId']?.toString().trim().isNotEmpty == true
            ? json['canonicalAccountId'].toString()
            : fallbackUid;
    return AuthSessionInfo(
      canonicalAccountId: canonical,
      anonUserId:
          json['anonUserId']?.toString().trim().isNotEmpty == true
              ? json['anonUserId'].toString()
              : canonical,
      deviceId: json['deviceId']?.toString() ?? deviceId,
      deviceTransferRequired:
          json['deviceTransferRequired'] == true ||
          activeDevice['transferRequired'] == true ||
          activeDeviceStatus == 'claimed_by_other_device',
      previousDeviceLabel:
          json['previousDeviceLabel']?.toString() ?? previousDeviceLabel,
    );
  }
}

class LinkedAuthProvider {
  const LinkedAuthProvider({
    required this.providerId,
    this.email,
    this.displayName,
  });

  final String providerId;
  final String? email;
  final String? displayName;
}

class CurrentAuthIdentity {
  const CurrentAuthIdentity({this.providerId, this.email, this.displayName});

  final String? providerId;
  final String? email;
  final String? displayName;
}

/// Authentication and canonical account coordination.
///
/// Firebase UID is treated as a provider-specific login key. The app owner,
/// billing, quota, and local alarm ownership should use canonicalAccountId.
class AuthService {
  static const String serverUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  static const String kakaoProviderId = String.fromEnvironment(
    'RINGINOUT_KAKAO_PROVIDER_ID',
    defaultValue: 'oidc.kakao',
  );
  static const String naverProviderId = String.fromEnvironment(
    'RINGINOUT_NAVER_PROVIDER_ID',
    defaultValue: 'oidc.naver',
  );
  static const String lineProviderId = String.fromEnvironment(
    'RINGINOUT_LINE_PROVIDER_ID',
    defaultValue: 'oidc.line',
  );
  static const String yahooProviderId = String.fromEnvironment(
    'RINGINOUT_YAHOO_PROVIDER_ID',
    defaultValue: 'oidc.yahoo',
  );
  static const String emailLinkUrl = String.fromEnvironment(
    'RINGINOUT_EMAIL_LINK_URL',
    defaultValue: 'https://ringgo-485705.web.app/email-sign-in',
  );
  static const String emailLinkDomain = String.fromEnvironment(
    'RINGINOUT_EMAIL_LINK_DOMAIN',
    defaultValue: '',
  );
  static const String naverLoginClientId = String.fromEnvironment(
    'RINGINOUT_NAVER_LOGIN_CLIENT_ID',
    defaultValue: '',
  );
  static const String lineLoginChannelId = String.fromEnvironment(
    'RINGINOUT_LINE_LOGIN_CHANNEL_ID',
    defaultValue: '',
  );
  static const String facebookAppId = String.fromEnvironment(
    'RINGINOUT_FACEBOOK_APP_ID',
    defaultValue: '',
  );
  static const String oauthCallbackScheme = 'ringinout';
  static const String naverOAuthRedirectUri = '$serverUrl/naverOAuthCallback';
  static const String lineOAuthRedirectUri = '$serverUrl/lineOAuthCallback';

  static const String _deviceIdKey = 'ringinout_device_id_v1';
  static const String _canonicalAccountIdKey = 'canonical_account_id_v1';
  static const String _anonUserIdKey = 'canonical_anon_user_id_v1';
  static const String _emailForLinkKey = 'email_link_pending_email_v1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '120131573076-0kutl2mvglpbs4kfbcu39m880phba48v.apps.googleusercontent.com',
  );

  AuthSessionInfo? _session;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get canonicalAccountId => _session?.canonicalAccountId;

  Future<String?> currentSignInProviderId() async =>
      (await currentAuthIdentity()).providerId;

  Future<CurrentAuthIdentity> currentAuthIdentity() async {
    final user = currentUser;
    if (user == null) return const CurrentAuthIdentity();

    String? providerId;
    String? email = user.email?.trim();
    String? displayName = user.displayName?.trim();

    try {
      final token = await user.getIdTokenResult(false);
      final claimProvider = token.claims?['provider_id']?.toString().trim();
      if (claimProvider != null && claimProvider.isNotEmpty) {
        providerId = claimProvider;
      }
      if (providerId == null || providerId.isEmpty) {
        final signInProvider = token.signInProvider?.trim();
        if (signInProvider != null && signInProvider.isNotEmpty) {
          providerId = signInProvider == 'password' ? 'email' : signInProvider;
        }
      }
      final claimEmail = token.claims?['provider_email']?.toString().trim();
      if ((email == null || email.isEmpty) &&
          claimEmail != null &&
          claimEmail.isNotEmpty) {
        email = claimEmail;
      }
      final claimDisplayName =
          token.claims?['provider_display_name']?.toString().trim();
      if ((displayName == null || displayName.isEmpty) &&
          claimDisplayName != null &&
          claimDisplayName.isNotEmpty) {
        displayName = claimDisplayName;
      }
    } catch (e) {
      debugPrint('Current auth identity unavailable: $e');
    }

    if ((providerId == null || providerId.isEmpty) &&
        user.providerData.isNotEmpty) {
      providerId = user.providerData.first.providerId;
    }
    if ((providerId == null || providerId.isEmpty) &&
        (email?.isNotEmpty == true)) {
      providerId = 'email';
    }
    return CurrentAuthIdentity(
      providerId: providerId,
      email: email?.isEmpty == true ? null : email,
      displayName: displayName?.isEmpty == true ? null : displayName,
    );
  }

  Future<String?> getStoredCanonicalAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_canonicalAccountIdKey);
  }

  Future<List<LinkedAuthProvider>> linkedProviders() async {
    final serverProviders = await _serverLinkedProviders();
    if (serverProviders.isNotEmpty) return serverProviders;
    return _firebaseLinkedProviders();
  }

  Future<List<LinkedAuthProvider>> _firebaseLinkedProviders() async {
    final user = currentUser;
    if (user == null) return const [];
    await user.reload();
    final refreshed = currentUser;
    if (refreshed == null) return const [];
    return refreshed.providerData
        .map(
          (provider) => LinkedAuthProvider(
            providerId: provider.providerId,
            email: provider.email,
            displayName: provider.displayName,
          ),
        )
        .toList();
  }

  Future<List<LinkedAuthProvider>> _serverLinkedProviders() async {
    final idToken = await getIdToken(forceRefresh: true);
    if (idToken == null) return const [];
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/getAccountLinkedProviders'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
      );
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawProviders = data['providers'];
      if (rawProviders is! List) return const [];
      return rawProviders
          .whereType<Map>()
          .where((raw) => raw['linked'] != false)
          .map(
            (raw) => LinkedAuthProvider(
              providerId: raw['providerId']?.toString() ?? '',
              email: raw['email']?.toString(),
              displayName: raw['displayName']?.toString(),
            ),
          )
          .where((provider) => provider.providerId.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Server linked providers unavailable: $e');
      return const [];
    }
  }

  Future<User?> signInWithGoogle({bool forceDeviceTransfer = false}) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In canceled');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID Token');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      rethrow;
    }
  }

  Future<User?> signInWithFacebook({bool forceDeviceTransfer = false}) =>
      _signInWithProvider(
        FacebookAuthProvider()..addScope('email'),
        forceDeviceTransfer: forceDeviceTransfer,
      );

  Future<User?> signInWithKakao({bool forceDeviceTransfer = false}) async {
    try {
      final token = await _signInToKakaoSdk();
      final customToken = await _exchangeKakaoTokenForFirebase(
        token.accessToken,
      );
      final userCredential = await _auth.signInWithCustomToken(customToken);
      return userCredential.user;
    } catch (e) {
      debugPrint('Kakao sign-in failed: $e');
      rethrow;
    }
  }

  Future<User?> signInWithNaver({bool forceDeviceTransfer = false}) async {
    if (naverLoginClientId.isEmpty) {
      throw StateError('Naver Login client ID is not configured');
    }
    final redirectUri = naverOAuthRedirectUri;
    final state = const Uuid().v4();
    final authUri = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': naverLoginClientId,
      'redirect_uri': redirectUri,
      'state': state,
    });

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: oauthCallbackScheme,
    );
    final callback = Uri.parse(callbackUrl);
    _throwIfOAuthError(callback);
    if (callback.queryParameters['state'] != state) {
      throw StateError('Naver OAuth state mismatch');
    }
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('Naver OAuth returned no code');
    }
    final customToken = await _exchangeOAuthCodeForFirebase(
      endpoint: 'signInWithNaverCode',
      code: code,
      redirectUri: redirectUri,
      state: state,
    );
    final credential = await _auth.signInWithCustomToken(customToken);
    return credential.user;
  }

  Future<User?> signInWithLine({bool forceDeviceTransfer = false}) async {
    if (lineLoginChannelId.isEmpty) {
      throw StateError('LINE Login channel ID is not configured');
    }
    final redirectUri = lineOAuthRedirectUri;
    final state = const Uuid().v4();
    final authUri = Uri.https('access.line.me', '/oauth2/v2.1/authorize', {
      'response_type': 'code',
      'client_id': lineLoginChannelId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'profile openid email',
      'bot_prompt': 'normal',
    });

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: oauthCallbackScheme,
    );
    final callback = Uri.parse(callbackUrl);
    _throwIfOAuthError(callback);
    if (callback.queryParameters['state'] != state) {
      throw StateError('LINE OAuth state mismatch');
    }
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('LINE OAuth returned no code');
    }
    final customToken = await _exchangeOAuthCodeForFirebase(
      endpoint: 'signInWithLineCode',
      code: code,
      redirectUri: redirectUri,
      state: state,
    );
    final credential = await _auth.signInWithCustomToken(customToken);
    return credential.user;
  }

  Future<User?> signInWithYahoo({bool forceDeviceTransfer = false}) =>
      throw UnsupportedError('Yahoo Japan sign-in is not configured yet');

  Future<User?> signInWithFacebookOAuth({
    bool forceDeviceTransfer = false,
  }) async {
    if (facebookAppId.isEmpty) {
      return signInWithFacebook(forceDeviceTransfer: forceDeviceTransfer);
    }
    final redirectUri = '$oauthCallbackScheme://oauth/facebook';
    final state = const Uuid().v4();
    final authUri = Uri.https('www.facebook.com', '/v20.0/dialog/oauth', {
      'response_type': 'code',
      'client_id': facebookAppId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'public_profile,email',
    });

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: oauthCallbackScheme,
    );
    final callback = Uri.parse(callbackUrl);
    _throwIfOAuthError(callback);
    if (callback.queryParameters['state'] != state) {
      throw StateError('Facebook OAuth state mismatch');
    }
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('Facebook OAuth returned no code');
    }
    final customToken = await _exchangeOAuthCodeForFirebase(
      endpoint: 'signInWithFacebookCode',
      code: code,
      redirectUri: redirectUri,
      state: state,
    );
    final credential = await _auth.signInWithCustomToken(customToken);
    return credential.user;
  }

  Future<void> sendEmailSignInLink(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) throw ArgumentError('Email is required');

    final settings = ActionCodeSettings(
      url: emailLinkUrl,
      handleCodeInApp: true,
      androidPackageName: 'com.bnt0514.ringinout',
      androidInstallApp: true,
      androidMinimumVersion: '20',
      linkDomain: emailLinkDomain.isEmpty ? null : emailLinkDomain,
    );

    await _auth.sendSignInLinkToEmail(
      email: trimmed,
      actionCodeSettings: settings,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailForLinkKey, trimmed);
  }

  bool isEmailSignInLink(String link) => _auth.isSignInWithEmailLink(link);

  Future<User?> signInWithEmailLink({
    required String emailLink,
    String? email,
    bool forceDeviceTransfer = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedEmail =
        (email?.trim().isNotEmpty == true)
            ? email!.trim()
            : prefs.getString(_emailForLinkKey);
    if (resolvedEmail == null || resolvedEmail.isEmpty) {
      throw Exception('Email is required to complete email-link sign-in');
    }

    final credential = await _auth.signInWithEmailLink(
      email: resolvedEmail,
      emailLink: emailLink,
    );
    await prefs.remove(_emailForLinkKey);
    return credential.user;
  }

  Future<User?> signInWithProviderName(
    RingAuthProvider provider, {
    bool forceDeviceTransfer = false,
  }) {
    switch (provider) {
      case RingAuthProvider.google:
        return signInWithGoogle(forceDeviceTransfer: forceDeviceTransfer);
      case RingAuthProvider.kakao:
        return signInWithKakao(forceDeviceTransfer: forceDeviceTransfer);
      case RingAuthProvider.naver:
        return signInWithNaver(forceDeviceTransfer: forceDeviceTransfer);
      case RingAuthProvider.line:
        return signInWithLine(forceDeviceTransfer: forceDeviceTransfer);
      case RingAuthProvider.yahoo:
        return signInWithYahoo(forceDeviceTransfer: forceDeviceTransfer);
      case RingAuthProvider.facebook:
        return signInWithFacebookOAuth(
          forceDeviceTransfer: forceDeviceTransfer,
        );
      case RingAuthProvider.email:
        throw UnsupportedError('Use sendEmailSignInLink first');
    }
  }

  Future<void> unlinkProvider(String providerId) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');
    final providers = await linkedProviders();
    if (providers.length <= 1) {
      throw Exception('Cannot unlink the last sign-in method');
    }
    await user.unlink(providerId);
    await notifyProviderUnlinked(providerId);
  }

  Future<void> linkAccountProvider({required String providerId}) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');
    final normalized = providerId.trim();
    if (normalized.isEmpty || normalized == 'password') {
      throw UnsupportedError('Email link must be added from the sign-in flow');
    }

    if ([
      kakaoProviderId,
      naverProviderId,
      lineProviderId,
      yahooProviderId,
      'kakao',
      'naver',
      'line',
      'yahoo',
    ].contains(normalized)) {
      throw UnsupportedError(
        'SDK sign-in providers cannot be linked through Firebase OIDC',
      );
    }

    if (normalized == 'google.com') {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google Sign-In canceled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await user.linkWithCredential(credential);
    } else {
      final provider =
          normalized == 'facebook.com'
              ? (FacebookAuthProvider()..addScope('email'))
              : (OAuthProvider(normalized)
                ..setScopes(['openid', 'profile', 'email']));
      await user.linkWithProvider(provider);
    }

    await ensureServerSession(forceRefresh: true);
  }

  Future<AuthSessionInfo?> ensureServerSession({
    bool forceRefresh = false,
    bool forceDeviceTransfer = false,
    bool allowDeviceAccountLink = false,
  }) async {
    final user = currentUser;
    if (user == null) return null;
    if (user.isAnonymous) {
      throw StateError('Anonymous sign-in is not allowed.');
    }
    if (!forceRefresh &&
        !forceDeviceTransfer &&
        _session != null &&
        _session!.canonicalAccountId.isNotEmpty) {
      return _session;
    }

    final deviceId = await getOrCreateDeviceId();
    final idToken = await user.getIdToken(true);
    if (idToken == null) throw Exception('Failed to get Firebase ID token');

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/createSession'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'idToken': idToken,
          'deviceId': deviceId,
          'platform': defaultTargetPlatform.name,
          'devicePlatform': defaultTargetPlatform.name,
          'forceDeviceTransfer': forceDeviceTransfer,
          'allowDeviceAccountLink': allowDeviceAccountLink,
        }),
      );

      if (response.statusCode == 409) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error']?.toString();
        if (error == 'device_account_link_required') {
          throw DeviceAccountLinkRequiredException(
            canonicalAccountId: data['canonicalAccountId']?.toString(),
            providerLinkedToDifferentAccount:
                data['providerLinkedToDifferentAccount'] == true,
          );
        }
        if (error == 'provider_account_conflict') {
          throw const ProviderAccountConflictException();
        }
      }

      if (response.statusCode != 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['error']?.toString() == 'sign_in_provider_required') {
            throw const SignInProviderRequiredException();
          }
        } on SignInProviderRequiredException {
          rethrow;
        } catch (_) {
          // Fall through to the generic server-session error below.
        }
        throw Exception('Server session failed: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final session = AuthSessionInfo.fromJson(
        data,
        deviceId: deviceId,
        fallbackUid: user.uid,
      );
      await _cacheSession(session);
      return session;
    } catch (e) {
      debugPrint('Server session creation failed: $e');
      rethrow;
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('Failed to get ID Token: $e');
      return null;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final deviceId = const Uuid().v4();
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  Future<void> signOut() async {
    _session = null;
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
      _signOutKakao(),
    ]);
    debugPrint('Signed out');
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    final idToken = await user.getIdToken(true);
    if (idToken != null) {
      await http.post(
        Uri.parse('$serverUrl/deleteAccount'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
    } catch (e) {
      debugPrint('Legacy Firestore data deletion failed: $e');
    }

    await user.delete();
    await HiveHelper.clearAllAccountScopedLocalData();
    _session = null;
    await Future.wait([_googleSignIn.signOut(), _signOutKakao()]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_canonicalAccountIdKey);
    await prefs.remove(_anonUserIdKey);
    debugPrint('Account deleted');
  }

  Future<kakao.OAuthToken> _signInToKakaoSdk() async {
    if (await kakao.isKakaoTalkInstalled()) {
      try {
        return await kakao.UserApi.instance.loginWithKakaoTalk();
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') {
          throw Exception('Kakao Sign-In canceled');
        }
        debugPrint('KakaoTalk sign-in failed, falling back to account: $e');
      } catch (e) {
        debugPrint('KakaoTalk sign-in failed, falling back to account: $e');
      }
    }
    return kakao.UserApi.instance.loginWithKakaoAccount();
  }

  Future<String> _exchangeKakaoTokenForFirebase(String accessToken) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(false);
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (e) {
      debugPrint('App Check token unavailable for Kakao sign-in: $e');
    }

    final response = await http.post(
      Uri.parse('$serverUrl/signInWithKakao'),
      headers: headers,
      body: jsonEncode({'accessToken': accessToken}),
    );
    if (response.statusCode != 200) {
      throw Exception('Kakao token exchange failed: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final customToken = data['customToken']?.toString();
    if (customToken == null || customToken.isEmpty) {
      throw Exception('Kakao token exchange returned no custom token');
    }
    return customToken;
  }

  Future<String> _exchangeOAuthCodeForFirebase({
    required String endpoint,
    required String code,
    required String redirectUri,
    required String state,
  }) async {
    final response = await http.post(
      Uri.parse('$serverUrl/$endpoint'),
      headers: await _jsonHeadersWithOptionalAppCheck(),
      body: jsonEncode({
        'code': code,
        'redirectUri': redirectUri,
        'state': state,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('$endpoint failed: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final customToken = data['customToken']?.toString();
    if (customToken == null || customToken.isEmpty) {
      throw Exception('$endpoint returned no custom token');
    }
    return customToken;
  }

  Future<Map<String, String>> _jsonHeadersWithOptionalAppCheck() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(false);
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (e) {
      debugPrint('App Check token unavailable for OAuth sign-in: $e');
    }
    return headers;
  }

  void _throwIfOAuthError(Uri callback) {
    final error = callback.queryParameters['error'];
    if (error == null || error.isEmpty) return;
    final description =
        callback.queryParameters['error_description'] ??
        callback.queryParameters['errorMessage'] ??
        error;
    throw Exception('OAuth failed: $description');
  }

  Future<void> _signOutKakao() async {
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      debugPrint('Kakao logout skipped: $e');
    }
  }

  Future<User?> _signInWithOidcProvider(
    String providerId, {
    required bool forceDeviceTransfer,
  }) {
    final provider = OAuthProvider(providerId)
      ..setScopes(['openid', 'profile', 'email']);
    return _signInWithProvider(
      provider,
      forceDeviceTransfer: forceDeviceTransfer,
    );
  }

  Future<User?> _signInWithProvider(
    AuthProvider provider, {
    required bool forceDeviceTransfer,
  }) async {
    final credential = await _auth.signInWithProvider(provider);
    return credential.user;
  }

  Future<void> notifyProviderUnlinked(String providerId) async {
    final idToken = await getIdToken(forceRefresh: true);
    if (idToken == null) return;
    try {
      await http.post(
        Uri.parse('$serverUrl/unlinkProvider'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({'providerId': providerId}),
      );
    } catch (e) {
      debugPrint('Provider unlink server sync failed: $e');
    }
  }

  Future<void> _cacheSession(AuthSessionInfo session) async {
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_canonicalAccountIdKey, session.canonicalAccountId);
    await prefs.setString(_anonUserIdKey, session.anonUserId);
  }
}
