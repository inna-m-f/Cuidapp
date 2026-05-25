import 'package:flutter/services.dart';

class RutFormatter extends TextInputFormatter {
  static String formatString(String rut) {
    if (rut.isEmpty) return '';
    String clean = rut.replaceAll(RegExp(r'[^0-9kK]'), '');
    if (clean.length > 9) {
      clean = clean.substring(0, 9);
    }
    if (clean.isEmpty) return '';

    String dv = clean.substring(clean.length - 1).toUpperCase();
    String digits = clean.substring(0, clean.length - 1);

    if (digits.isEmpty) {
      return dv;
    } else {
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
      return '$formattedDigits-$dv';
    }
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si el texto nuevo está vacío, permitirlo
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Obtener los caracteres válidos
    String cleanNew = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');
    String cleanOld = oldValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');

    // Si ya tiene el máximo de 9 dígitos y se intenta agregar más, rechazar el cambio.
    // Esto evita que el teclado nativo retenga caracteres "ocultos".
    if (cleanNew.length > 9) {
      if (cleanOld.length >= 9 && cleanNew.length > cleanOld.length) {
        return oldValue;
      }
      // Si fue un pegado (paste) largo en campo vacío o incompleto, truncar a 9
      cleanNew = cleanNew.substring(0, 9);
    }

    if (cleanNew.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // Formatear a RUT (ej: 12.345.678-9)
    String formatted = '';
    String dv = cleanNew.substring(cleanNew.length - 1).toUpperCase();
    String digits = cleanNew.substring(0, cleanNew.length - 1);

    if (digits.isEmpty) {
      formatted = dv;
    } else {
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

    // Mantener siempre el cursor al final de la cadena formateada
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
