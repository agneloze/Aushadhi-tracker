import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
        _showResultDialog(expiryDate);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(DateTime? date) {
    final TextEditingController dateController = TextEditingController(
      text: date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('CONFIRM EXPIRY (पुष्टि करें)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scanned Date:', style: TextStyle(fontSize: 12)),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                hintText: 'DD/MM/YYYY',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            const Text('Please verify the date before saving.', style: TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('RE-SCAN', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // Logic to save to Drift database will go here
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('SAVE STOCK'),
          ),
        ],
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
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryOrange, width: 2),
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
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text('CAPTURE & SCAN (स्कैन करें)'),
      ),
    );
  }
}
