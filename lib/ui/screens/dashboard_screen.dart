import 'package:flutter/material.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:aushadhi_tracker/ui/screens/scan_screen.dart';
import 'package:aushadhi_tracker/ui/screens/warning_tab.dart';
import 'package:aushadhi_tracker/ui/screens/settings_tab.dart';
import 'package:aushadhi_tracker/ui/screens/reports_tab.dart';
import 'package:aushadhi_tracker/services/reports_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }

    try {
      final now = DateTime.now();
      final threeMonthsFromNow = now.add(const Duration(days: 90));

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
          _expiringItems = expiringList.take(3).toList();
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _onAuthChanged() {
    setState(() => _isLoadingStats = true);
    _fetchStats();
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const WarningTab();
      case 2:
        return const ReportsTab();
      case 3:
        return SettingsTab(onAuthChanged: _onAuthChanged);
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/logo.png', height: 36, width: 36, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AUSHADHI TRACKER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                Text('Jan Aushadhi · FIFO Manager', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        elevation: 10,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  // ── HOME TAB ──────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    Text('Welcome,', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text(
                      isLoggedIn ? (user.email ?? 'User') : 'Guest',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (!isLoggedIn) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedIndex = 3),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Sign In'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Stat cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'TOTAL BATCHES',
                    value: !isLoggedIn ? '—' : (_isLoadingStats ? '...' : '$_totalBatches'),
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'EXPIRING SOON',
                    value: !isLoggedIn ? '—' : (_isLoadingStats ? '...' : '$_expiringSoon'),
                    icon: Icons.timer_outlined,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Grid
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
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
                    // Refresh stats when returning from scan (optimistic refresh)
                    _fetchStats();
                  },
                ),
                _buildActionCard(
                  context,
                  title: 'FIFO\nALERTS',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.primaryOrange,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Critical Expiries
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CRITICAL EXPIRIES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: const Text('VIEW ALL →', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildExpiriesSection(isLoggedIn),
            ),
            const SizedBox(height: 32),

            // Quick Export (only when logged in)
            if (isLoggedIn) ...[
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('PDF export failed.'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF REPORT'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.borderGrey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('CSV export failed.'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.table_chart),
                      label: const Text('CSV DATA'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.borderGrey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiriesSection(bool isLoggedIn) {
    if (!isLoggedIn) {
      return Container(
        key: const ValueKey('guest'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.borderGrey), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Sign in to see expiry data synced across devices.', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          ],
        ),
      );
    }

    if (_isLoadingStats) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.borderGrey), borderRadius: BorderRadius.circular(8)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_expiringItems.isEmpty) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.borderGrey), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: Colors.green[400]),
            const SizedBox(height: 12),
            const Text('All clear! No critical expiries.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('No medicines expiring within 90 days.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('data'),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.borderGrey), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: _expiringItems.map((item) {
          final date = DateTime.parse(item['expiry_date']);
          final formattedDate = DateFormat('MM/yyyy').format(date);
          final daysLeft = date.difference(DateTime.now()).inDays;
          return Column(
            children: [
              _buildExpiryItem(item['batch_name'] ?? 'Unknown', 'Exp: $formattedDate', daysLeft),
              if (item != _expiringItems.last) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryItem(String name, String date, int daysLeft) {
    Color urgencyColor = daysLeft < 0 ? Colors.red : (daysLeft < 30 ? Colors.red : AppTheme.primaryOrange);
    String urgencyText = daysLeft < 0 ? 'EXPIRED' : '${daysLeft}d left';

    return ListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(date, style: TextStyle(color: urgencyColor, fontSize: 12, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: urgencyColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(urgencyText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: urgencyColor)),
      ),
    );
  }
}
