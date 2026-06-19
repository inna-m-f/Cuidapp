import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../services/session_service.dart';
import '../../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class NoCentroScreen extends StatefulWidget {
  const NoCentroScreen({Key? key}) : super(key: key);

  @override
  State<NoCentroScreen> createState() => _NoCentroScreenState();
}

class _NoCentroScreenState extends State<NoCentroScreen> {
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en el usuario para redirigir al Home si es aceptado en algún centro
    final uid = SessionService().uid;
    if (uid.isNotEmpty) {
      _userSubscription = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .snapshots()
          .listen((snapshot) async {
        if (!mounted) return;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final List<String> centros = List<String>.from(data['centros'] ?? []);
          if (centros.isNotEmpty) {
            // Re-inicializar sesión con los nuevos centros y roles
            Map<String, String> rolesMap = {};
            if (data.containsKey('roles') && data['roles'] != null) {
              final Map<String, dynamic> rawRoles = data['roles'] as Map<String, dynamic>;
              rolesMap = rawRoles.map((key, value) => MapEntry(key, value.toString()));
            }
            if (rolesMap.isEmpty) {
              final String legacyRol = data['rol'] ?? 'cuidador';
              for (final c in centros) {
                rolesMap[c] = legacyRol;
              }
            }

            await SessionService().initialize(
              uid: uid,
              nombre: data['nombre'] ?? data['name'] ?? '',
              rut: data['rut'] ?? '',
              rol: rolesMap[centros.first] ?? data['rol'] ?? 'cuidador',
              centroId: centros.first,
              centros: centros,
              roles: rolesMap,
            );

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService();
    final String uid = session.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Sin Centro Activo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.blue,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Error al cargar datos del usuario.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> invitaciones = List<String>.from(data['invitaciones'] ?? []);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.business_outlined, size: 80, color: AppTheme.blue),
                const SizedBox(height: 24),
                Text(
                  '¡Hola, ${session.nombre}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Actualmente no perteneces a ningún centro de cuidado. Puedes pedirle a un administrador que te añada buscando tu RUT:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    AppTheme.formatRut(session.rut),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.blue, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Invitaciones Pendientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: invitaciones.isEmpty
                      ? const Center(
                          child: Text(
                            'No tienes invitaciones pendientes.\nLas invitaciones de administradores aparecerán aquí en tiempo real.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black38, fontSize: 14, height: 1.4),
                          ),
                        )
                      : ListView.separated(
                          itemCount: invitaciones.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final String cId = invitaciones[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('centros').doc(cId).get(),
                              builder: (context, centerSnap) {
                                String nombreCentro = 'Cargando centro...';
                                if (centerSnap.hasData && centerSnap.data!.exists) {
                                  final cData = centerSnap.data!.data() as Map<String, dynamic>?;
                                  nombreCentro = cData?['nombre'] ?? cId;
                                }
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreCentro,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => _dbService.rejectInvitation(uid, cId),
                                            child: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () => _dbService.acceptInvitation(uid, cId),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.green,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            ),
                                            child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _handleLogout();
                              },
                              child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
