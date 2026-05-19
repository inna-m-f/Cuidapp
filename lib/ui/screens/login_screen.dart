import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores y estado
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _centroController = TextEditingController(); 
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // Evitar campos vacíos
    if (_rutController.text.trim().isEmpty || _centroController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); 

    try {
      await _authService.signIn(_rutController.text.trim(), _centroController.text.trim());
      
      
      if (!mounted) return;
      
      // Si todo sale bien, navegamos al Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString(), style: const TextStyle(color: Colors.white)), 
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _rutController.dispose();
    _centroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.blue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
              child: Column(
                children: const [
                  Text('CuidApp', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppTheme.white)),
                  SizedBox(height: 10),
                  Text('Gestión de cuidado de adultos\nmayores', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppTheme.white, height: 1.3)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40.0, left: 30.0, right: 30.0, bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _rutController, // <-- Asignamos controlador
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(hintText: '12.345.678-9', hintStyle: TextStyle(color: Colors.black38)),
                      ),
                      const SizedBox(height: 25),
                      const Text('Nombre del centro (Contraseña)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _centroController, 
                        obscureText: true, 
                        decoration: const InputDecoration(hintText: 'Centro de cuidado', hintStyle: TextStyle(color: Colors.black38)),
                      ),
                      const SizedBox(height: 40),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55, 
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin, 
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: AppTheme.white)
                            : const Text('Ingresar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Colors.black45, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}