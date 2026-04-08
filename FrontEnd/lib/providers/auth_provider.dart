import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dio/dio.dart';

import '../models/user.dart';
import '../repositories/base_repository.dart';
import '../repositories/user_repository.dart';

void _log(String msg) {
  debugPrint('[AuthProvider] $msg');
  developer.log(msg, name: 'AuthProvider');
}

class AuthProvider extends ChangeNotifier {
  final UserRepository _api;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AppUser? _user;
  bool _isLoading = true;
  String? _errorMessage;

  /// Guard flag: when true, _onAuthStateChanged is a no-op.
  /// Set during signIn / signUp so the listener can't race with them.
  bool _manualAuthInProgress = false;

  /// True only until the very first authStateChanges event is processed.
  /// Used by the router to know when the initial session check is done.
  bool _initialCheckDone = false;

  /// Optional async callback invoked *before* Firebase signOut so callers
  /// (e.g. FCM device-token unregister) can still use a valid auth session.
  Future<void> Function()? _onBeforeSignOut;
  set onBeforeSignOut(Future<void> Function()? cb) => _onBeforeSignOut = cb;

  /// Optional callback invoked *after* sign-out completes (user cleared) but
  /// before notifyListeners — used to clear provider caches so no stale data
  /// from User A leaks into User B's session.
  VoidCallback? _onAfterSignOut;
  set onAfterSignOut(VoidCallback? cb) => _onAfterSignOut = cb;

  AuthProvider(this._api) {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get initialCheckDone => _initialCheckDone;
  String? get errorMessage => _errorMessage;

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _log('_onAuthStateChanged: uid=${firebaseUser?.uid}, manual=$_manualAuthInProgress, user=${_user?.email}');

    // ── Guard 1: explicit signIn/signUp owns the flow ──
    if (_manualAuthInProgress) {
      _log('_onAuthStateChanged: skipping — manual auth in progress');
      return;
    }

    // ── Guard 2: we already have a verified user; don't re-fetch ──
    if (firebaseUser != null && _user != null) {
      _log('_onAuthStateChanged: skipping — user already set');
      if (!_initialCheckDone) {
        _initialCheckDone = true;
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    // ── Firebase signed out ──
    if (firebaseUser == null) {
      _user = null;
      _isLoading = false;
      _initialCheckDone = true;
      notifyListeners();
      return;
    }

    // ── Cached Firebase session on app start — try to restore from backend ──
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _api.getMe();
      _log('_onAuthStateChanged: backend /me response: $data');
      _user = data;
      _errorMessage = null;
    } catch (e) {
      _log('_onAuthStateChanged: failed to fetch /me: $e');
      _log('_onAuthStateChanged: signing out stale Firebase session');
      await _firebaseAuth.signOut();
      _user = null;
    }

    _initialCheckDone = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Sign up with email & password, then register with backend.
  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? phone,
    String? termsAcceptedAt,
    String? birthday,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    _manualAuthInProgress = true;
    notifyListeners();

    try {
      _log('signUp: creating Firebase account for $email (role=$role)...');
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _log('signUp: Firebase account created, uid=${cred.user?.uid}');

      if (displayName != null && cred.user != null) {
        await cred.user!.updateDisplayName(displayName);
      }

      // Get ID token and register with backend
      final idToken = await cred.user?.getIdToken();
      _log('signUp: got ID token (length=${idToken?.length}), calling backend /auth/verify...');

      final verifyResp = await _api.verifyToken(idToken!, role,
          displayName: displayName, termsAcceptedAt: termsAcceptedAt,
          birthday: birthday);
      _log('signUp: backend verify response: $verifyResp');

      // Update phone if provided
      if (phone != null) {
        _log('signUp: updating phone on backend...');
        await _api.updateMe(UpdateProfileRequest(phone: phone));
      }

      // Now fetch full profile
      final meData = await _api.getMe();
      _log('signUp: backend /me response: $meData');
      _user = meData;
      _errorMessage = null;
    } on FirebaseAuthException catch (e) {
      _log('signUp: FirebaseAuthException: ${e.code} - ${e.message}');
      _errorMessage = _mapFirebaseError(e.code);
      _user = null;
    } catch (e, stackTrace) {
      _log('signUp: ERROR: $e');
      _log('signUp: STACKTRACE: $stackTrace');
      _errorMessage = _mapBackendError(e, context: 'registration');
      _user = null;
    }

    _manualAuthInProgress = false;
    _isLoading = false;
    notifyListeners();
  }

  /// Sign in with email & password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    _manualAuthInProgress = true;
    notifyListeners();

    try {
      _log('signIn: signing in $email...');
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _log('signIn: Firebase sign-in success, uid=${cred.user?.uid}');

      // Fetch backend profile — this is the actual verification step.
      // Only set _user (and thus isAuthenticated) if backend confirms.
      final meData = await _api.getMe();
      _log('signIn: backend /me response: $meData');
      _user = meData;
      _errorMessage = null;
    } on FirebaseAuthException catch (e) {
      _log('signIn: FirebaseAuthException: ${e.code} - ${e.message}');
      _errorMessage = _mapFirebaseError(e.code);
      _user = null;
    } catch (e, stackTrace) {
      _log('signIn: ERROR: $e');
      _log('signIn: STACKTRACE: $stackTrace');
      _errorMessage = _mapBackendError(e, context: 'sign-in');
      // Firebase succeeded but backend rejected — sign out of Firebase
      // so the cached session doesn't auto-redirect next time.
      await _firebaseAuth.signOut();
      _user = null;
    }

    _manualAuthInProgress = false;
    _isLoading = false;
    notifyListeners();
  }

  /// Re-fetch the backend user profile (e.g. after role change).
  Future<void> refreshUser() async {
    try {
      final meData = await _api.getMe();
      _user = meData;
      notifyListeners();
    } catch (e) { debugPrint(e.toString()); }
  }

  /// Sign out of Firebase and clear local state.
  Future<void> signOut() async {
    _log('signOut: signing out...');
    // Run pre-signout hook (e.g. unregister FCM device token) while
    // the Firebase session is still alive and Dio can attach auth headers.
    if (_onBeforeSignOut != null) {
      try {
        await _onBeforeSignOut!();
      } catch (e) {
        _log('signOut: pre-signout hook error (continuing): $e');
      }
    }
    await _firebaseAuth.signOut();
    _user = null;
    _errorMessage = null;
    _onAfterSignOut?.call();
    notifyListeners();
  }

  /// Clear error message (e.g. when navigating away).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Map backend/network errors to user-friendly messages.
  String _mapBackendError(Object e, {required String context}) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      // Extract backend detail if present (e.g. "Birthday is required")
      final detail = e.response?.data;
      if (detail is Map && detail.containsKey('detail')) {
        final msg = detail['detail'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (status == 401) {
        return context == 'sign-in'
            ? 'Account not found on server. Please sign up first.'
            : 'Session could not be verified. Please try again.';
      }
      if (status == 429) return 'Too many attempts. Please wait a moment.';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Cannot reach server. Check your internet connection.';
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        return 'Server is not responding. Please try again.';
      }
      return ApiError.extractMessage(e);
    }
    final s = e.toString();
    // Strip "Exception: " prefix if present
    final cleaned = s.startsWith('Exception: ') ? s.substring(11) : s;
    return cleaned.isNotEmpty ? cleaned : 'Something went wrong during $context.';
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication error: $code';
    }
  }
}
