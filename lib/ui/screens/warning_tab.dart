import 'package:flutter/material.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarningTab extends StatefulWidget {
  const WarningTab({super.key});

  @override
  State<WarningTab> createState() => _WarningTabState();
}

class _WarningTabState extends State<WarningTab> {
  late Future<List<Map<String, dynamic>>> _upcomingExpiriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _upcomingExpiriesFuture = _fetchUpcomingExpiries();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUpcomingExpiries() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final threeMonthsFromNow = now.add(const Duration(days: 90));

    final response = await Supabase.instance.client
        .from('stock_batches')
        .select()
        .lte('expiry_date', threeMonthsFromNow.toIso8601String())
        .order('expiry_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    if (!isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Sign in to see FIFO alerts', style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Expiry warnings are available after signing in from Settings.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _upcomingExpiriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Failed to load alerts.', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryOrange),
                  ),
                ],
              ),
            ),
          );
        }

        final batches = snapshot.data ?? [];

        if (batches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Colors.green[400]),
                  const SizedBox(height: 16),
                  const Text('All Clear!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'No medicines expiring in the next 90 days.\n(अगले 90 दिनों में कोई दवा समाप्त नहीं हो रही है)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: () async => _refreshData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              final expiryDate = batch['expiry_date'] != null ? DateTime.parse(batch['expiry_date']) : DateTime.now();
              final daysLeft = expiryDate.difference(DateTime.now()).inDays;

              Color cardColor = Colors.white;
              Color textColor = AppTheme.textBlack;
              Color accentColor = AppTheme.primaryOrange;
              String urgencyText = '${daysLeft}d left';

              if (daysLeft < 0) {
                cardColor = Colors.red.shade50;
                textColor = Colors.red.shade900;
                accentColor = Colors.red;
                urgencyText = 'EXPIRED';
              } else if (daysLeft < 30) {
                cardColor = Colors.red.shade50;
                textColor = Colors.red.shade900;
                accentColor = Colors.red;
              } else if (daysLeft < 60) {
                cardColor = Colors.orange.shade50;
                textColor = Colors.orange.shade900;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: AppTheme.borderGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(Icons.warning_rounded, color: accentColor, size: 32),
                  title: Text(
                    batch['batch_name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Expires: ${DateFormat('dd MMM yyyy').format(expiryDate)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text('Drug Code: ${batch['drug_code'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(urgencyText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accentColor)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
