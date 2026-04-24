import 'package:flutter/material.dart';
import 'package:aushadhi_tracker/core/database/local_db.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';

// Create a global instance for the UI to use (simple service locator pattern)
// Note: In a production app with Riverpod/Bloc, this would be injected.
late AppDatabase db;

class WarningTab extends StatefulWidget {
  const WarningTab({super.key});

  @override
  State<WarningTab> createState() => _WarningTabState();
}

class _WarningTabState extends State<WarningTab> {
  late Future<List<MedicineBatch>> _upcomingExpiriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _upcomingExpiriesFuture = db.getUpcomingExpiries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIFO ALERTS (चेतावनी)'),
        backgroundColor: AppTheme.primaryOrange,
      ),
      body: FutureBuilder<List<MedicineBatch>>(
        future: _upcomingExpiriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}'));
          }

          final batches = snapshot.data ?? [];

          if (batches.isEmpty) {
            return const Center(
              child: Text(
                'No medicines expiring in the next 90 days!\n(अगले 90 दिनों में कोई दवा समाप्त नहीं हो रही है)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
              
              // Color coding based on urgency
              Color cardColor = Colors.white;
              Color textColor = AppTheme.textBlack;
              if (daysLeft < 30) {
                cardColor = Colors.red.shade50;
                textColor = Colors.red.shade900;
              } else if (daysLeft < 60) {
                cardColor = Colors.orange.shade50;
                textColor = Colors.orange.shade900;
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: AppTheme.borderGrey),
                  borderRadius: BorderRadius.zero,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.warning_rounded, color: AppTheme.primaryOrange, size: 36),
                  title: Text(
                    'Batch: ${batch.batchNumber}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Expires: ${DateFormat('dd MMM yyyy').format(batch.expiryDate)}'),
                      Text('Quantity: ${batch.quantity} units'),
                    ],
                  ),
                  trailing: Text(
                    '$daysLeft Days Left',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: daysLeft < 30 ? Colors.red : AppTheme.primaryOrange,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: AppTheme.primaryOrange,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
