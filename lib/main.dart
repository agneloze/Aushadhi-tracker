import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:aushadhi_tracker/ui/screens/dashboard_screen.dart';
import 'package:aushadhi_tracker/ui/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://oniurthtwpvhgflzzmac.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uaXVydGh0d3B2aGdmbHp6bWFjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NjYzMTYsImV4cCI6MjA5MjU0MjMxNn0.mIdWrvpkNntr6kRWLHzDCHj-ndejmjNkdp88SY3woGA',
  );

  runApp(const AushadhiTrackerApp());
}

class AushadhiTrackerApp extends StatelessWidget {
  const AushadhiTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aushadhi Tracker',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
          );
        }

        final session = snapshot.data?.session;
        
        if (session != null) {
          final user = session.user;
          
          // Check for email verification
          // Note: If you disable 'Confirm Email' in Supabase, this check won't block access.
          if (user.emailConfirmedAt == null && user.appMetadata['provider'] == 'email') {
            return const EmailVerificationPendingScreen();
          }
          
          return const DashboardScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

class EmailVerificationPendingScreen extends StatelessWidget {
  const EmailVerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: AppTheme.primaryBlue),
            const SizedBox(height: 24),
            const Text(
              'Verify Your Email',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
            ),
            const SizedBox(height: 16),
            const Text(
              'We sent a link to your email. Please check your inbox and verify your account to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                if (user?.email != null) {
                  Supabase.instance.client.auth.resend(type: OtpType.signup, email: user!.email!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email resent!')),
                  );
                }
              },
              child: const Text('Resend Email', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
