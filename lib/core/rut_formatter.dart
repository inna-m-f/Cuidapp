import 'package:flutter/services.dart';

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si el texto está vacío, no formatear
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remover todos los caracteres excepto números y la letra K/k
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');

    if (cleanText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // Limitar el largo del RUT a 9 caracteres (8 dígitos + 1 verificador)
    if (cleanText.length > 9) {
      cleanText = cleanText.substring(0, 9);
    }

    String formatted = '';
    String dv = cleanText.substring(cleanText.length - 1).toUpperCase();
    String digits = cleanText.substring(0, cleanText.length - 1);

    if (digits.isEmpty) {
      formatted = dv;
    } else {
      // Dar formato de miles a la parte numérica
      String formattedDigits = '';
      int count = 0;
      for (int i = digits.length - 1; i >= 0; i--) {
        formattedDigits = digits[i] + formattedDigits;
        count++;
        if (count == 3 && i > 0) {
          formattedDigits = '.$formattedDigits';
          count = 0;
        }
      }
      formatted = '$formattedDigits-$dv';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
