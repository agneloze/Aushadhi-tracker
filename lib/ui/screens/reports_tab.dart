import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:aushadhi_tracker/services/reports_service.dart';
import 'package:intl/intl.dart';

enum ReportFilter { today, week, month, all }

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  ReportFilter _activeFilter = ReportFilter.all;
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_activeFilter) {
      case ReportFilter.today:
        return DateTime(now.year, now.month, now.day);
      case ReportFilter.week:
        return now.subtract(const Duration(days: 7));
      case ReportFilter.month:
        return DateTime(now.year, now.month - 1, now.day);
      case ReportFilter.all:
        return DateTime(2000);
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final startDate = _getStartDate();
      final response = await Supabase.instance.client
          .from('stock_batches')
          .select()
          .gte('scanned_at', startDate.toIso8601String())
          .order('scanned_at', ascending: false);

      if (mounted) {
        setState(() {
          _batches = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Failed to load report data.', isError: true);
      }
    }
  }

  Future<void> _exportPDF() async {
    if (_batches.isEmpty) {
      _showSnack('No data to export.', isError: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ReportsService().generateAndSharePDF(_batches);
      _showSnack('PDF report generated!');
    } catch (e) {
      _showSnack('PDF export failed.', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCSV() async {
    if (_batches.isEmpty) {
      _showSnack('No data to export.', isError: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ReportsService().generateAndShareCSV(_batches);
      _showSnack('CSV data generated!');
    } catch (e) {
      _showSnack('CSV export failed.', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;

    if (!isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Sign in to access reports',
                style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Your scan logs and export tools are available after signing in from Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Filter Chips
            _buildFilterRow(),
            const SizedBox(height: 20),

            // Summary Card
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildSummaryCard(),
            ),
            const SizedBox(height: 20),

            // Export Buttons
            const Text('EXPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportPDF,
                    icon: _isExporting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF REPORT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.borderGrey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportCSV,
                    icon: _isExporting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.table_chart),
                    label: const Text('CSV DATA'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.borderGrey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scan Log List
            const Text('SCAN LOG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildLogList(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── FILTER ROW ──────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportFilter.values.map((filter) {
          final isActive = _activeFilter == filter;
          final label = switch (filter) {
            ReportFilter.today => 'Today',
            ReportFilter.week => 'This Week',
            ReportFilter.month => 'This Month',
            ReportFilter.all => 'All Time',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label, style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF2D3436),
                fontSize: 13,
              )),
              selected: isActive,
              selectedColor: AppTheme.primaryBlue,
              backgroundColor: Colors.white,
              side: BorderSide(color: isActive ? AppTheme.primaryBlue : AppTheme.borderGrey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) {
                setState(() => _activeFilter = filter);
                _loadData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SUMMARY CARD ────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    final now = DateTime.now();
    int expired = 0;
    int expiringSoon = 0;
    int safe = 0;
    for (var b in _batches) {
      if (b['expiry_date'] != null) {
        final d = DateTime.parse(b['expiry_date']);
        final daysLeft = d.difference(now).inDays;
        if (daysLeft < 0) {
          expired++;
        } else if (daysLeft <= 90) {
          expiringSoon++;
        } else {
          safe++;
        }
      }
    }

    return Container(
      key: ValueKey(_activeFilter), // force animation on filter change
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _summaryItem('${_batches.length}', 'Total', AppTheme.primaryBlue),
          _divider(),
          _summaryItem('$expired', 'Expired', Colors.red.shade700),
          _divider(),
          _summaryItem('$expiringSoon', 'Warning', AppTheme.primaryOrange),
          _divider(),
          _summaryItem('$safe', 'Safe', Colors.green.shade700),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: AppTheme.borderGrey);

  // ── LOG LIST ────────────────────────────────────────────────────────────

  Widget _buildLogList() {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    if (_batches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.borderGrey), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No scan entries found for this period.', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final batch = _batches[index];
        final expiryDate = batch['expiry_date'] != null ? DateTime.parse(batch['expiry_date']) : null;
        final scannedAt = batch['scanned_at'] != null ? DateTime.parse(batch['scanned_at']) : null;
        final daysLeft = expiryDate?.difference(DateTime.now()).inDays;

        Color statusColor = Colors.green;
        String statusText = 'Safe';
        if (daysLeft != null) {
          if (daysLeft < 0) {
            statusColor = Colors.red;
            statusText = 'Expired';
          } else if (daysLeft <= 90) {
            statusColor = AppTheme.primaryOrange;
            statusText = '${daysLeft}d left';
          }
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.borderGrey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch['batch_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'Exp: ${expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate) : 'N/A'} · Scanned: ${scannedAt != null ? DateFormat('dd MMM').format(scannedAt) : 'N/A'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
        );
      },
    );
  }
}
