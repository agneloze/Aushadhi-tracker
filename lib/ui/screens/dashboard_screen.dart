import 'package:flutter/material.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:aushadhi_tracker/ui/screens/scan_screen.dart';
import 'package:aushadhi_tracker/ui/screens/warning_tab.dart';
import 'package:aushadhi_tracker/services/reports_service.dart';
import 'package:aushadhi_tracker/main.dart'; // To access the global db instance

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AUSHADHI TRACKER (औषधि ट्रैकर)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dashboard Statistics (Quick Overview)
            _buildStatCard(
              title: 'TOTAL BATCHES (कुल बैच)',
              value: '124',
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'EXPIRING SOON (जल्द समाप्त होने वाला)',
              value: '12',
              color: AppTheme.primaryOrange,
            ),
            
            const SizedBox(height: 32),
            
            // Primary Actions
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScanScreen()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('SCAN MEDICINE (दवा स्कैन करें)'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WarningTab()),
                );
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('FIFO ALERTS (एफ.आई.एफ.ओ. अलर्ट)'),
            ),
            
            const SizedBox(height: 32),
            
            // Secondary Actions (Reports)
            const Text('REPORTS (रिपोर्ट)', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final batches = await db.getUpcomingExpiries(); // Fetch data
                      await ReportsService().generateAndSharePDF(batches);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final batches = await db.getUpcomingExpiries(); // Fetch data
                      await ReportsService().generateAndShareCSV(batches);
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('CSV'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderGrey),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
