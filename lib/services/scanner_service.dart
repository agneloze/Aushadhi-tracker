import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:aushadhi_tracker/config/app_secrets.dart';

class ScannerService {
  Future<DateTime?> processImage(String imagePath) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: AppSecrets.geminiApiKey,
      );

      final imageBytes = await File(imagePath).readAsBytes();
      final prompt = TextPart(
          'Analyze this image of a medicine pack. Find the expiry date. '
          'Return ONLY the date in the format DD/MM/YYYY. '
          'If you only find the month and year, return the last day of that month (e.g. 10/2025 -> 31/10/2025). '
          'If no date is found, return the word NONE.');

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final result = response.text?.trim() ?? 'NONE';
      
      if (result == 'NONE') {
        return null;
      }

      return _parseDate(result);
    } catch (e) {
      throw Exception('Gemini OCR failed: $e');
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(dateStr);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    // No specific resources to close for generative AI in this context
  }
}
