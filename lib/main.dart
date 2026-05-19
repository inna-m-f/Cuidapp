import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'ui/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Inicializar Firebase aquí más adelante
  runApp(const CuidApp());
}

class CuidApp extends StatelessWidget {
  const CuidApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CuidApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(), // Inyectamos la nueva pantalla de Login
    );
  }
}