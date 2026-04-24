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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras.first, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _takePictureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final DateTime? expiryDate = await _scannerService.processImage(image.path);

      if (mounted) {
        if (expiryDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No date found. Please re-scan with clearer focus.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          _showResultDialog(expiryDate);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(DateTime date) {
    // Unfocus any active field BEFORE showing dialog — prevents IME loop
    FocusScope.of(context).unfocus();

    final TextEditingController dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(date),
    );
    final TextEditingController batchController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('CONFIRM DETAILS (पुष्टि करें)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Batch / Medicine Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: batchController,
                autofocus: false, // ← Prevents IME loop
                decoration: const InputDecoration(
                  hintText: 'e.g. Paracetamol 500mg',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Expiry Date (एक्सपायरी डेट):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: dateController,
                autofocus: false, // ← Prevents IME loop
                decoration: const InputDecoration(
                  hintText: 'DD/MM/YYYY',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 8),
              const Text(
                'Verify both fields before saving.',
                style: TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus(); // clean up before pop
                Navigator.pop(dialogContext);
              },
              child: const Text('RE-SCAN', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      FocusScope.of(dialogContext).unfocus();
                      final batchName = batchController.text.trim();
                      final dateText = dateController.text.trim();

                      if (batchName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter batch/medicine name.')),
                        );
                        return;
                      }

                      // Parse date back from the (possibly edited) text field
                      DateTime? finalDate;
                      try {
                        finalDate = DateFormat('dd/MM/yyyy').parse(dateText);
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid date format. Use DD/MM/YYYY.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        await Supabase.instance.client.from('stock_batches').insert({
                          'batch_name': batchName,
                          'expiry_date': finalDate.toIso8601String(),
                          'scanned_at': DateTime.now().toIso8601String(),
                        });

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context); // back to dashboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ $batchName saved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
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
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SCAN PACK (पैक स्कैन करें)')),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // Viewfinder Overlay
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryOrange, width: 2),
                borderRadius: BorderRadius.zero,
              ),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    'EXP DATE ZONE',
                    style: TextStyle(color: AppTheme.primaryOrange, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text(
                'Point camera at the Expiry Date text\n(कैमरे को एक्सपायरी डेट की ओर रखें)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _takePictureAndProcess,
        backgroundColor: AppTheme.primaryOrange,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        label: _isProcessing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text('CAPTURE & SCAN (स्कैन करें)'),
      ),
    );
  }
}
