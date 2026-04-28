import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Stream of [AuthState] to track login/logout events.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  
  /// Get current authenticated user.
  User? get currentUser => _supabase.auth.currentUser;

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email and password.
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Trigger Google OAuth flow.
  /// On Web, this handles the redirect automatically.
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // redirectTo is handled automatically by Supabase on Web if configured in Dashboard
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
