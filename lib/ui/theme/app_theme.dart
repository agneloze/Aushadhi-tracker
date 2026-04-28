import 'package:flutter/material.dart';

class AppTheme {
  // Jan Aushadhi Brand Colors
  static const Color primaryOrange = Color(0xFFF58220);
  static const Color primaryBlue = Color(0xFF0054A6);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textBlack = Color(0xFF212121);
  static const Color borderGrey = Color(0xFFE0E0E0);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false, // Keeping it classic/simple for govt app feel
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: backgroundWhite,
      fontFamily: 'Roboto', // Default basic font
      
      // Sharp corners on all components
      cardTheme: const CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        color: backgroundWhite,
      ),
      
      buttonTheme: const ButtonThemeData(
        buttonColor: primaryOrange,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textBlack, fontWeight: FontWeight.bold, fontSize: 24),
        titleLarge: TextStyle(color: textBlack, fontWeight: FontWeight.w600, fontSize: 18),
        bodyLarge: TextStyle(color: textBlack, fontSize: 16),
        bodySmall: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}
