import 'package:flutter/material.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const Scaffold(
        body: Center(
          child: Text('CuidApp Inicializada Correctamente'),
        ),
      ),
    );
  }
}