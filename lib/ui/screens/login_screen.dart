import 'package:flutter/material.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo azul base (cabecera)
      backgroundColor: AppTheme.blue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sección Superior (Logotipo y textos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
              child: Column(
                children: [
                  const Text(
                    'CuidApp',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Gestión de cuidado de adultos\nmayores',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Sección Inferior (Formulario Blanco)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40.0, left: 30.0, right: 30.0, bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label y TextField RUT
                      const Text(
                        'RUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TextField(
                        decoration: InputDecoration(
                          hintText: '12.345.678-9',
                          hintStyle: TextStyle(color: Colors.black38),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Label y TextField Nombre del centro
                      const Text(
                        'Nombre del centro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TextField(
                        decoration: InputDecoration(
                          hintText: 'Centro de cuidado',
                          hintStyle: TextStyle(color: Colors.black38),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Botón Ingresar Verde
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Implementar lógica de validación e inicio de sesión
                          },
                          child: const Text(
                            'Ingresar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Texto de recuperación
                      Center(
                        child: TextButton(
                          onPressed: () {
                            // TODO: Navegar a recuperación de contraseña
                          },
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 15,
                            ),
                          ),
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