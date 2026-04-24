import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';

class ScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Primary regex patterns for expiry dates
  final RegExp _datePattern = RegExp(
    r'(\d{1,2})[\/\-\. ](\d{1,2})[\/\-\. ](\d{2,4})|(\d{1,2})[\/\-\. ](\d{2,4})',
    caseSensitive: false,
  );

  Future<DateTime?> processImage(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    DateTime? bestMatch;

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final String text = line.text.toUpperCase();
        
        // Check for keywords like "EXP", "EXPIRY", "VALID"
        if (text.contains('EXP') || text.contains('VAL')) {
          final match = _datePattern.firstMatch(text);
          if (match != null) {
            final dateStr = match.group(0)!;
            final parsedDate = _parseDate(dateStr);
            if (parsedDate != null) return parsedDate;
          }
        }
      }
    }

    // Fallback: If no keywords found, return the first valid date-like string
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final match = _datePattern.firstMatch(line.text);
        if (match != null) {
          final date = _parseDate(match.group(0)!);
          if (date != null) return date;
        }
      }
    }

    return null;
  }

  DateTime? _parseDate(String dateStr) {
    // Clean the string
    final cleanStr = dateStr.replaceAll(RegExp(r'[ \-\.]'), '/');
    
    // Try various formats
    final formats = [
      'dd/MM/yyyy',
      'MM/yyyy',
      'dd/MM/yy',
      'MM/yy',
    ];

    for (var format in formats) {
      try {
        final date = DateFormat(format).parse(cleanStr);
        // If it's just MM/YYYY, set to last day of month
        if (format == 'MM/yyyy' || format == 'MM/yy') {
          return DateTime(date.year, date.month + 1, 0);
        }
        return date;
      } catch (_) {}
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
