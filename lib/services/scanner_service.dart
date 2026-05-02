import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:aushadhi_tracker/config/app_secrets.dart';
import 'package:flutter/foundation.dart';

class ScannerService {
  /// Processes an image and tries to extract the expiry date.
  /// Returns null if no date could be found.
  Future<DateTime?> processImage(String imagePath) async {
    // Web platform: File system not available, always return null for manual entry
    if (kIsWeb) return null;

    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: AppSecrets.geminiApiKey,
      );

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;

      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) return null;

      // Determine MIME type
      final ext = imagePath.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final prompt = TextPart(
        'You are an OCR tool for medicine packs sold in India. '
        'Find the expiry date printed on this medicine pack or box. '
        'It may appear as: "EXP", "Exp Date", "Expiry", "Use before", "Best before", or similar. '
        'Common formats: MM/YYYY, MM-YYYY, MMM-YYYY, MM/YY, DD/MM/YYYY, "Sep 2025", "Sept 2025", "MAR 2026". '
        'Return ONLY the expiry date in DD/MM/YYYY format. '
        'If you find only month and year (e.g. 09/2025), use the last day of that month (30/09/2025). '
        'If you find a 2-digit year (e.g. 09/25), assume 20xx (25 → 2025). '
        'If you cannot find any date, return exactly: NONE',
      );

      final imagePart = DataPart(mimeType, imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final result = response.text?.trim() ?? 'NONE';
      debugPrint('[ScannerService] Gemini response: $result');

      if (result == 'NONE' || result.isEmpty) return null;

      return _parseDate(result);
    } catch (e) {
      debugPrint('[ScannerService] Error: $e');
      return null; // Return null so UI can offer manual entry instead of crashing
    }
  }

  DateTime? _parseDate(String raw) {
    // Clean up the string
    final str = raw.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Try multiple formats in order of preference
    final formats = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('MM/yyyy'),
      DateFormat('MM-yyyy'),
      DateFormat('MMM-yyyy'),
      DateFormat('MMM yyyy'),
      DateFormat('MMMM yyyy'),
      DateFormat('dd/MM/yy'),
    ];

    for (final fmt in formats) {
      try {
        final date = fmt.parseStrict(str);
        // If month+year only format, use last day of month
        if (fmt.pattern == 'MM/yyyy' || fmt.pattern == 'MM-yyyy' ||
            fmt.pattern == 'MMM-yyyy' || fmt.pattern == 'MMM yyyy' ||
            fmt.pattern == 'MMMM yyyy') {
          return DateTime(date.year, date.month + 1, 0); // last day of month
        }
        // Fix 2-digit year
        if (date.year < 2000) {
          return DateTime(date.year + 2000, date.month, date.day);
        }
        return date;
      } catch (_) {}
    }

    debugPrint('[ScannerService] Could not parse date: $raw');
    return null;
  }

  void dispose() {}
}
