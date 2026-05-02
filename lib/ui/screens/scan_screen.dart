import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aushadhi_tracker/services/scanner_service.dart';
import 'package:aushadhi_tracker/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  final ScannerService _scannerService = ScannerService();
  bool _isProcessing = false;
  bool _cameraFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.high);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  Future<void> _takePictureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final image = await _controller!.takePicture();
      final DateTime? expiryDate = await _scannerService.processImage(image.path);
      if (mounted) {
        if (expiryDate == null) {
          _showScanFailedOptions();
        } else {
          _showResultDialog(expiryDate);
        }
      }
    } catch (e) {
      if (mounted) _showScanFailedOptions();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Shows a bottom sheet when scan fails, offering manual entry.
  void _showScanFailedOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('Could Not Read Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'The camera could not detect a date on this pack. You can try scanning again or enter the date manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openManualEntry();
                },
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('Enter Date Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Opens manual date entry — shows the confirm dialog with a date picker.
  void _openManualEntry() {
    // Default to 1 year from now as a starting point
    final defaultDate = DateTime.now().add(const Duration(days: 365));
    _showResultDialog(defaultDate, isManual: true);
  }

  Future<Iterable<Map<String, dynamic>>> _searchMedicines(String query) async {
    if (query.length < 2) return const [];
    try {
      final response = await Supabase.instance.client
          .from('medicines_master')
          .select('drug_code, generic_name, unit_size')
          .ilike('generic_name', '%$query%')
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return const [];
    }
  }

  void _showResultDialog(DateTime date, {bool isManual = false}) {
    final screenContext = context;
    FocusScope.of(screenContext).unfocus();

    final TextEditingController dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(date),
    );
    final TextEditingController medicineController = TextEditingController();
    String? selectedDrugCode;
    bool isSaving = false;
    DateTime selectedDate = date;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              Icon(isManual ? Icons.edit_rounded : Icons.check_circle_outline, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(isManual ? 'MANUAL ENTRY' : 'CONFIRM DETAILS', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Medicine search ──
                const Text('Medicine Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return _searchMedicines(textEditingValue.text);
                  },
                  displayStringForOption: (option) => '${option['generic_name']} (${option['unit_size'] ?? ''})',
                  onSelected: (option) {
                    selectedDrugCode = option['drug_code'] as String?;
                    medicineController.text = '${option['generic_name']}';
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    controller.addListener(() {
                      if (medicineController.text != controller.text) {
                        medicineController.text = controller.text;
                        if (selectedDrugCode != null) selectedDrugCode = null;
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search medicine name...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 280),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Text(
                                    '${option['generic_name']} (${option['unit_size'] ?? ''})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ── Expiry Date ──
                const Text('Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        autofocus: false,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'MM/YYYY',
                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date picker button
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2035),
                          helpText: 'Select Expiry Date',
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                            dateController.text = DateFormat('dd/MM/yyyy').format(picked);
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Pick', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                if (!isManual) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Date was scanned automatically. Verify it is correct.',
                    style: TextStyle(color: Colors.green[700], fontSize: 11),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'You can also type a date in DD/MM/YYYY format.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext);
              },
              child: Text(isManual ? 'CANCEL' : 'RE-SCAN', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      FocusScope.of(dialogContext).unfocus();
                      final batchName = medicineController.text.trim();
                      final dateText = dateController.text.trim();

                      if (batchName.isEmpty) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          SnackBar(
                            content: const Text('Please select or enter a medicine name.'),
                            backgroundColor: Colors.orange.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      DateTime? finalDate;
                      // Try to parse from text field first
                      for (final fmt in ['dd/MM/yyyy', 'MM/yyyy', 'd/M/yyyy']) {
                        try {
                          finalDate = DateFormat(fmt).parseStrict(dateText);
                          break;
                        } catch (_) {}
                      }
                      finalDate ??= selectedDate; // fallback to picker value

                      if (finalDate == null) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          const SnackBar(content: Text('Invalid date. Please pick or type DD/MM/YYYY.')),
                        );
                        return;
                      }

                      final currentUser = Supabase.instance.client.auth.currentUser;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          SnackBar(
                            content: const Text('Please sign in from Settings to save scans.'),
                            backgroundColor: Colors.orange.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await Supabase.instance.client.from('stock_batches').insert({
                          'user_id': currentUser.id,
                          'batch_name': batchName,
                          'drug_code': selectedDrugCode,
                          'expiry_date': finalDate.toIso8601String(),
                          'scanned_at': DateTime.now().toIso8601String(),
                        });

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          Navigator.pop(screenContext);
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            SnackBar(
                              content: Text('✓ $batchName saved!'),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(screenContext).showSnackBar(
                          SnackBar(
                            content: const Text('Save failed. Check your connection and try again.'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SAVE STOCK'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Camera unavailable — show manual entry only
    if (_cameraFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('ADD MEDICINE STOCK')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.no_photography_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Camera not available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('You can still add stock entries manually.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openManualEntry,
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Enter Date Manually'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Camera initializing
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Starting camera...'),
          ],
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SCAN MEDICINE PACK'),
        actions: [
          TextButton.icon(
            onPressed: _openManualEntry,
            icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
            label: const Text('Manual', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // Viewfinder overlay
          Center(
            child: Container(
              width: 300,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryOrange, width: 2.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'AIM AT EXPIRY DATE',
                    style: TextStyle(color: AppTheme.primaryOrange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ),

          // Corner marks
          ...[ Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight]
              .map((align) => Center(child: FractionalTranslation(
                    translation: Offset(align == Alignment.topLeft || align == Alignment.bottomLeft ? -0.55 : 0.55,
                                       align == Alignment.topLeft || align == Alignment.topRight ? -0.95 : 0.95),
                    child: Container(width: 20, height: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          top: align.y < 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                          bottom: align.y > 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                          left: align.x < 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                          right: align.x > 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                        ),
                      ),
                    ),
                  ))),

          // Instructions bar
          Positioned(
            bottom: 120,
            left: 0, right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const Text(
                'Point camera at the Expiry Date printed on the pack.\nIf scan fails, use the Manual button above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _takePictureAndProcess,
        backgroundColor: AppTheme.primaryOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        icon: _isProcessing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.qr_code_scanner_rounded),
        label: Text(_isProcessing ? 'Scanning...' : 'SCAN EXPIRY DATE'),
      ),
    );
  }
}
