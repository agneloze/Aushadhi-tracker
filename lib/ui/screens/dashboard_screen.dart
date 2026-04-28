import 'package:flutter/material.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:aushadhi_tracker/ui/screens/scan_screen.dart';
import 'package:aushadhi_tracker/ui/screens/warning_tab.dart';
import 'package:aushadhi_tracker/services/reports_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalBatches = 0;
  int _expiringSoon = 0;
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _expiringItems = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final now = DateTime.now();
      final threeMonthsFromNow = now.add(const Duration(days: 90));

      // Fetch all batches
      final batches = await Supabase.instance.client
          .from('stock_batches')
          .select('id, batch_name, expiry_date')
          .order('expiry_date', ascending: true);

      List<Map<String, dynamic>> expiringList = [];
      for (var batch in batches) {
        if (batch['expiry_date'] != null) {
          final expiryDate = DateTime.parse(batch['expiry_date']);
          if (expiryDate.isBefore(threeMonthsFromNow)) {
            expiringList.add(batch);
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalBatches = batches.length;
          _expiringSoon = expiringList.length;
          _expiringItems = expiringList.take(3).toList(); // Show top 3
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text('AUSHADHI TRACKER'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome Back,', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text(user?.email ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Stat Row (Side-by-side)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'TOTAL BATCHES',
                    value: _isLoadingStats ? '...' : '$_totalBatches',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'EXPIRING SOON',
                    value: _isLoadingStats ? '...' : '$_expiringSoon',
                    icon: Icons.timer_outlined,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Action Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  title: 'SCAN\nMEDICINE',
                  icon: Icons.qr_code_scanner_rounded,
                  color: AppTheme.primaryBlue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'FIFO\nALERTS',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.primaryOrange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WarningTab())),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Critical Expiries Section
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CRITICAL EXPIRIES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Text('VIEW ALL', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: _isLoadingStats
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  : _expiringItems.isEmpty
                      ? const Padding(padding: EdgeInsets.all(16), child: Text('No critical expiries right now.'))
                      : Column(
                          children: _expiringItems.map((item) {
                            final date = DateTime.parse(item['expiry_date']);
                            final formattedDate = DateFormat('MM/yyyy').format(date);
                            return Column(
                              children: [
                                _buildExpiryItem(item['batch_name'] ?? 'Unknown', 'Exp: $formattedDate', '1 Batch'), // Grouping by batch name is an enhancement for later
                                if (item != _expiringItems.last) const Divider(height: 1),
                              ],
                            );
                          }).toList(),
                        ),
            ),
            
            const SizedBox(height: 32),
            
            // Quick Export
            const Text('QUICK EXPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final batches = await Supabase.instance.client.from('stock_batches').select();
                        await ReportsService().generateAndSharePDF(List<Map<String, dynamic>>.from(batches));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF REPORT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.borderGrey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final batches = await Supabase.instance.client.from('stock_batches').select();
                        await ReportsService().generateAndShareCSV(List<Map<String, dynamic>>.from(batches));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating CSV: $e')));
                      }
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('CSV DATA'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.borderGrey),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: const BorderSide(color: AppTheme.borderGrey),
          right: const BorderSide(color: AppTheme.borderGrey),
          bottom: const BorderSide(color: AppTheme.borderGrey),
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
              Icon(icon, color: color.withOpacity(0.5), size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryItem(String name, String date, String count) {
    return ListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(date, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Colors.grey[100],
        child: Text(count, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
