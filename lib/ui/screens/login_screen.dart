import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'no_centro_screen.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../providers/session_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(); 
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isCheckingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _loadLastLoggedEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  Future<void> _loadLastLoggedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('last_logged_email');
      if (lastEmail != null && lastEmail.isNotEmpty) {
        setState(() {
          _emailController.text = lastEmail;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAutoLogin() async {
    setState(() {
      _isLoading = true;
      _isCheckingAutoLogin = true;
    });
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final hasCachedSession = await sessionProvider.loadSession();
      if (hasCachedSession) {
        if (!mounted) return;
        if (sessionProvider.centros.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NoCentroScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          List<String> centros = [];
          if (data.containsKey('centros')) {
            centros = List<String>.from(data['centros']);
          } else if (data.containsKey('centroId') && data['centroId'] != null && data['centroId'].toString().isNotEmpty) {
            centros = [data['centroId']];
          }

          Map<String, String> rolesMap = {};
          if (data.containsKey('roles') && data['roles'] != null) {
            final Map<String, dynamic> rawRoles = data['roles'] as Map<String, dynamic>;
            rolesMap = rawRoles.map((key, value) => MapEntry(key, value.toString()));
          }

          if (rolesMap.isEmpty) {
            final String legacyRol = data['rol'] ?? 'cuidador';
            if (centros.isNotEmpty) {
              for (final c in centros) {
                rolesMap[c] = legacyRol;
              }
            } else {
              rolesMap[''] = legacyRol;
            }
          }

          await sessionProvider.initialize(
            uid: user.uid,
            nombre: data['nombre'] ?? data['name'] ?? '',
            rut: data['rut'] ?? '',
            rol: rolesMap[centros.isNotEmpty ? centros.first : ''] ?? data['rol'] ?? 'cuidador',
            centroId: centros.isNotEmpty ? centros.first : '',
            centros: centros,
            roles: rolesMap,
          );

          if (!mounted) return;

          if (data['mustChangePassword'] == true) {
            await _showForceChangePasswordDialog(context, user.uid);
          }

          if (!mounted) return;

          if (centros.isEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NoCentroScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          await _authService.signOut();
        }
      }
    } catch (e) {
      await _authService.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingAutoLogin = false;
        });
      }
    }
  }

  Future<void> _showForceChangePasswordDialog(BuildContext context, String uid) async {
    final TextEditingController passCtrl1 = TextEditingController();
    final TextEditingController passCtrl2 = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Actualizar Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Es necesario que cambies tu contraseña temporal para continuar.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passCtrl1,
                      obscureText: true,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Nueva Contraseña'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl2,
                      obscureText: true,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Confirmar Contraseña'),
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: AppTheme.blue),
                    ]
                  ],
                ),
                actions: isSaving
                    ? []
                    : [
                        ElevatedButton(
                          onPressed: () async {
                            final p1 = passCtrl1.text.trim();
                            final p2 = passCtrl2.text.trim();
                            if (p1.isEmpty || p2.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor completa todos los campos')),
                              );
                              return;
                            }
                            if (p1.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
                              );
                              return;
                            }
                            if (p1 != p2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Las contraseñas no coinciden')),
                              );
                              return;
                            }

                            setStateDialog(() => isSaving = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await user.updatePassword(p1);
                                await FirebaseFirestore.instance
                                    .collection('usuarios')
                                    .doc(uid)
                                    .update({'mustChangePassword': false});
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contraseña actualizada con éxito'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al cambiar contraseña: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setStateDialog(() => isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Actualizar Contraseña',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); 

    try {
      await _authService.signIn(_emailController.text.trim(), _passwordController.text.trim());
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_logged_email', _emailController.text.trim());
      } catch (_) {}

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>;
          if (userData['mustChangePassword'] == true) {
            await _showForceChangePasswordDialog(context, user.uid);
          }
        }
      }

      if (!mounted) return;

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      if (sessionProvider.centros.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NoCentroScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(
        backgroundColor: AppTheme.blue,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Cargando sesión...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.blue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 35.0, horizontal: 20.0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'images/icono.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('CuidaFlow', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppTheme.white)),
                  const SizedBox(height: 10),
                  const Text('Gestión de cuidado de adultos\nmayores', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppTheme.white, height: 1.3)),
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
                      const Text('Correo Electrónico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(hintText: 'ejemplo@correo.com', hintStyle: TextStyle(color: Colors.black38)),
                      ),
                      const SizedBox(height: 25),
                      const Text('Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true, 
                        decoration: const InputDecoration(hintText: 'Ingresa tu contraseña', hintStyle: TextStyle(color: Colors.black38)),
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