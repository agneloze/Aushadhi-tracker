import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:aushadhi_tracker/ui/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Initialization
  // Replace these with your actual Project URL and Anon Key
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
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
