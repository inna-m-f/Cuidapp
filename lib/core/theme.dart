import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color white = Color(0xFFFFFFFF);
  static const Color blue = Color(0xFF0E51D7);
  static const Color green = Color(0xFF47C869);

  static String formatRut(String rut) {
    if (rut.isEmpty) return rut;
    final String cleaned = rut.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (cleaned.length < 2) return cleaned;
    final String dv = cleaned.substring(cleaned.length - 1);
    final String number = cleaned.substring(0, cleaned.length - 1);
    
    String formattedNumber = '';
    int count = 0;
    for (int i = number.length - 1; i >= 0; i--) {
      formattedNumber = number[i] + formattedNumber;
      count++;
      if (count == 3 && i > 0) {
        formattedNumber = '.' + formattedNumber;
        count = 0;
      }
    }
    return '$formattedNumber-$dv';
  }

  static ThemeData get theme {
    final baseTextTheme = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: false,
      primaryColor: blue,
      scaffoldBackgroundColor: white,
      colorScheme: const ColorScheme.light(
        primary: blue,
        secondary: green,
        background: white,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(baseTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: blue,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        labelStyle: GoogleFonts.nunito(color: Colors.grey.shade600),
        hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
    );
  }
}