import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../providers/session_provider.dart';
import 'login_screen.dart';
import 'patient_detail_screen.dart';
import 'admin_cuidadores_screen.dart';
import '../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Stream<QuerySnapshot> _pacientesStream;
  List<String>? _lastSyncedPatientIds;
  final Map<String, StreamSubscription<QuerySnapshot>> _taskSubscriptions = {};
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  List<String>? _previousInvitations;
  Timer? _offlineTimer;
  final ValueNotifier<bool> _showOfflineNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    _pacientesStream = _dbService.getPacientesStream(
      centroId: session.centroId,
      rol: session.activeRole, 
      uidCuidador: session.uid,
    );

    // Escuchar nuevas invitaciones en tiempo real para lanzar notificación local
    _userSubscription = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(session.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final List<String> currentInvitations = List<String>.from(data['invitaciones'] ?? []);
      final List<String> currentCentros = List<String>.from(data['centros'] ?? []);
      final Map<String, dynamic> rawRoles = data['roles'] ?? {};
      final Map<String, String> currentRoles = rawRoles.map((key, value) => MapEntry(key, value.toString()));

      // Mantener SessionProvider sincronizado con los datos en tiempo real de Firestore
      await session.updateSessionData(
        centros: currentCentros,
        roles: currentRoles,
      );

      // Gatillar reconstrucción para que el Drawer reaccione al cambio de centros
      if (mounted) {
        setState(() {});
      }

      final List<String> invitesToNotify = [];
      if (_previousInvitations == null) {
        invitesToNotify.addAll(currentInvitations);
      } else {
        invitesToNotify.addAll(currentInvitations.where((id) => !_previousInvitations!.contains(id)));
      }

      for (final cId in invitesToNotify) {
        try {
          final centerDoc = await FirebaseFirestore.instance.collection('centros').doc(cId).get();
          String nombreCentro = cId;
          if (centerDoc.exists) {
            final cData = centerDoc.data() as Map<String, dynamic>?;
            nombreCentro = cData?['nombre'] ?? cId;
          }
          await NotificationService.showImmediateNotification(
            id: cId.hashCode,
            title: 'Nueva Invitación de Centro',
            body: 'Has recibido una invitación para unirte a "$nombreCentro".',
          );
        } catch (e) {
          debugPrint('Error al mostrar notificación de invitación: $e');
        }
      }
      _previousInvitations = currentInvitations;
    });
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    _showOfflineNotifier.dispose();
    _searchController.dispose();
    _userSubscription?.cancel();
    for (final subscription in _taskSubscriptions.values) {
      subscription.cancel();
    }
    _taskSubscriptions.clear();
    super.dispose();
  }

  void _updateTaskSubscriptions(String uidCuidador, List<QueryDocumentSnapshot> patientDocs) {
    final List<String> currentIds = patientDocs.map((d) => d.id).toList();

    final keysToRemove = _taskSubscriptions.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in keysToRemove) {
      _taskSubscriptions[id]?.cancel();
      _taskSubscriptions.remove(id);
    }

    for (final doc in patientDocs) {
      final String patientId = doc.id;
      if (!_taskSubscriptions.containsKey(patientId)) {
        final subscription = FirebaseFirestore.instance
            .collection('pacientes')
            .doc(patientId)
            .collection('tareas')
            .snapshots()
            .listen((tasksSnapshot) {
              NotificationService.syncCaregiverReminders(
                uidCuidador: uidCuidador,
                patientDocs: patientDocs,
              );
            });
        _taskSubscriptions[patientId] = subscription;
      }
    }
  }

  String _removeDiacritics(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐdÌÍÎÏìíîïÙÚÛÜùúûüÑñÝýÿ';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeoCcDdIIIIiiiiUUUUuuuuNnYyy';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medic')) return Icons.medication_rounded;
    if (lower.contains('alimen') || lower.contains('comida') || lower.contains('desayuno') || lower.contains('almuerzo') || lower.contains('colación') || lower.contains('colacion') || lower.contains('once') || lower.contains('cena')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('higiene') || lower.contains('aseo') || lower.contains('baño') || lower.contains('bano')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('salida') || lower.contains('visita')) {
      return Icons.groups_rounded;
    }
    return Icons.checklist_rounded;
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medic')) return const Color(0xFF7B1FA2);
    if (lower.contains('alimen') || lower.contains('comida') || lower.contains('desayuno') || lower.contains('almuerzo') || lower.contains('colación') || lower.contains('colacion') || lower.contains('once') || lower.contains('cena')) {
      return const Color(0xFF00C853);
    }
    if (lower.contains('higiene') || lower.contains('aseo') || lower.contains('baño') || lower.contains('bano')) {
      return const Color(0xFF2979FF);
    }
    if (lower.contains('salida') || lower.contains('visita')) {
      return const Color(0xFF00A86B);
    }
    return AppTheme.blue;
  }

  String _getDiaSemanaActual() {
    final int weekday = DateTime.now().weekday;
    switch (weekday) {
      case DateTime.monday: return 'lunes';
      case DateTime.tuesday: return 'martes';
      case DateTime.wednesday: return 'miercoles';
      case DateTime.thursday: return 'jueves';
      case DateTime.friday: return 'viernes';
      case DateTime.saturday: return 'sabado';
      case DateTime.sunday: return 'domingo';
      default: return 'lunes';
    }
  }

  bool _isTaskScheduledForToday(Map<String, dynamic> data) {
    final List<String> diasSemana = List<String>.from(data['diasSemana'] ?? []);
    final String hoy = _getDiaSemanaActual();
    
    final normalizedDias = diasSemana.map((d) {
      return d.trim().toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u');
    }).toList();

    return normalizedDias.contains(hoy);
  }

  bool _isCompletedToday(Map<String, dynamic> data) {
    final DateTime nowDt = DateTime.now();
    final String fechaActual = '${nowDt.year}-${nowDt.month.toString().padLeft(2, '0')}-${nowDt.day.toString().padLeft(2, '0')}';
    final completedDates = data['completedDates'];

    if (completedDates is Map<String, dynamic>) {
      return completedDates[fechaActual] == true;
    }
    return false;
  }

  Widget _buildPatientTaskProgress(String patientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pacientes')
          .doc(patientId)
          .collection('tareas')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final Map<String, Map<String, int>> grouped = {};

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (!_isTaskScheduledForToday(data)) continue;

          final category = (data['category'] ?? data['categoria'] ?? data['tipo'] ?? data['type'] ?? 'Medicamentos').toString();

          grouped.putIfAbsent(category, () => {'completed': 0, 'total': 0});
          grouped[category]!['total'] = grouped[category]!['total']! + 1;

          if (_isCompletedToday(data)) {
            grouped[category]!['completed'] = grouped[category]!['completed']! + 1;
          }
        }

        if (grouped.isEmpty) {
          return const Text(
            'Sin tareas para hoy',
            style: TextStyle(fontSize: 12, color: Colors.black45, fontStyle: FontStyle.italic),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: grouped.entries.map((entry) {
            final category = entry.key;
            final completed = entry.value['completed']!;
            final total = entry.value['total']!;
            final color = _getCategoryColor(category);
            final isComplete = total > 0 && completed == total;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isComplete ? color.withOpacity(0.35) : Colors.transparent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getCategoryIcon(category), size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(
                    '$completed/$total',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded, size: 13, color: color),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController ageCtrl = TextEditingController();
    final TextEditingController roomCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Agregar Nuevo Paciente', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', hintText: 'Ej: María González López'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Edad', hintText: 'Ej: 78'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: roomCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Habitación / Ubicación', hintText: 'Ej: Habitación 102'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final age = ageCtrl.text.trim();
                final room = roomCtrl.text.trim();

                if (name.isEmpty || age.isEmpty || room.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos')));
                  return;
                }

                List<String> parts = name.split(' ');
                String initials = '';
                if (parts.isNotEmpty && parts[0].isNotEmpty) initials += parts[0][0];
                if (parts.length > 1 && parts[1].isNotEmpty) initials += parts[1][0];
                if (initials.isEmpty) initials = 'P';

                String details = '$age años • $room';

                try {
                  await _dbService.addPaciente(
                    centroId: Provider.of<SessionProvider>(context, listen: false).centroId,
                    name: name,
                    details: details,
                    initials: initials,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paciente agregado correctamente'), backgroundColor: Colors.green));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditPatientDialog(BuildContext context, String patientId, String currentName, String currentDetails) {
    final TextEditingController nameCtrl = TextEditingController(text: currentName);
    final TextEditingController detailsCtrl = TextEditingController(text: currentDetails);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Editar Paciente', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre Completo'),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: detailsCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Detalles (Edad / Habitación)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final details = detailsCtrl.text.trim();

                if (name.isEmpty || details.isEmpty) return;

                List<String> parts = name.split(' ');
                String initials = '';
                if (parts.isNotEmpty && parts[0].isNotEmpty) initials += parts[0][0];
                if (parts.length > 1 && parts[1].isNotEmpty) initials += parts[1][0];
                if (initials.isEmpty) initials = 'P';

                try {
                  await _dbService.updatePacienteData(patientId, {
                    'name': name,
                    'details': details,
                    'initials': initials.toUpperCase(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blue),
              child: const Text('Actualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, SessionProvider session) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: AppTheme.blue),
                  accountName: Text(session.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text('RUT: ${AppTheme.formatRut(session.rut)}'),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      session.nombre.isNotEmpty ? session.nombre[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 24, color: AppTheme.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (session.isRealAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined, color: Colors.black87),
                    title: const Text('Gestionar Cuidadores'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCuidadoresScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      session.activeRole == 'admin' ? Icons.visibility_outlined : Icons.admin_panel_settings, 
                      color: Colors.black87
                    ),
                    title: Text(session.activeRole == 'admin' ? 'Cambiar a vista Cuidador' : 'Volver a vista Admin'),
                    subtitle: Text(
                      session.activeRole == 'admin' ? 'Verás la app como un trabajador' : 'Recuperar controles de edición',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      String newRole = session.activeRole == 'admin' ? 'cuidador' : 'admin';
                      await session.setActiveRole(newRole);
                      
                      if (!context.mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                    },
                  ),
                ],
                
                if (session.centros.length > 1) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Centros Disponibles',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                  ...session.centros.map((cId) {
                    return CenterListTile(
                      centroId: cId,
                      activeCentroId: session.centroId,
                      onTap: () async {
                        await session.setActiveCentro(cId);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                      },
                    );
                  }).toList(),
                ],

                // Sección de invitaciones pendientes dentro del Drawer
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').doc(session.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final List<String> invitaciones = List<String>.from(data?['invitaciones'] ?? []);
                    if (invitaciones.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 10, bottom: 5),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Text(
                                  'Nuevas Invitaciones',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.green, fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.green,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${invitaciones.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        ...invitaciones.map((cId) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('centros').doc(cId).get(),
                            builder: (context, centerSnap) {
                              String nombreCentro = session.getCenterName(cId);
                              if (centerSnap.hasData && centerSnap.data!.exists) {
                                final cData = centerSnap.data!.data() as Map<String, dynamic>?;
                                final String fetchedName = cData?['nombre'] ?? cId;
                                if (fetchedName != cId && fetchedName != nombreCentro) {
                                  nombreCentro = fetchedName;
                                  session.saveCenterName(cId, fetchedName);
                                }
                              }
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.mail_outline_rounded, color: AppTheme.green),
                                title: Text(nombreCentro, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                subtitle: const Text('Toca para ver', style: TextStyle(fontSize: 11, color: Colors.black45)),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Text('Invitación de $nombreCentro', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      content: Text('¿Deseas unirte al centro de cuidado "$nombreCentro"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await DatabaseService().rejectInvitation(session.uid, cId);
                                          },
                                          child: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await DatabaseService().acceptInvitation(session.uid, cId);
                                            // Cambiar automáticamente al nuevo centro aceptado
                                            await session.setActiveCentro(cId);
                                            if (context.mounted) {
                                              Navigator.pop(context); // Cerrar el Drawer
                                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.green,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),

                // Estado del Centro (resumen de pacientes y cuidadores en tiempo real)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('centros').doc(session.centroId).get(),
                  builder: (context, centroSnap) {
                    String nombreCentro = session.getCenterName(session.centroId);
                    if (centroSnap.hasData && centroSnap.data!.exists) {
                      final cData = centroSnap.data!.data() as Map<String, dynamic>?;
                      final String fetchedName = cData?['nombre'] ?? session.centroId;
                      if (fetchedName != session.centroId && fetchedName != nombreCentro) {
                        nombreCentro = fetchedName;
                        session.saveCenterName(session.centroId, fetchedName);
                      }
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('pacientes').where('centroId', isEqualTo: session.centroId).snapshots(),
                      builder: (context, pacientesSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('usuarios').where('centros', arrayContains: session.centroId).snapshots(),
                          builder: (context, cuidadoresSnap) {
                            final int totalPacientes = pacientesSnap.hasData ? pacientesSnap.data!.docs.length : 0;
                            final int totalCuidadores = cuidadoresSnap.hasData ? cuidadoresSnap.data!.docs.length : 0;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.blue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: AppTheme.blue.withOpacity(0.1), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estado: $nombreCentro',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.blue),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.people_outline_rounded, size: 16, color: Colors.black54),
                                            const SizedBox(width: 8),
                                            const Text('Pacientes Activos', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                          ],
                                        ),
                                        Text(
                                          '$totalPacientes',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.badge_outlined, size: 16, color: Colors.black54),
                                            const SizedBox(width: 8),
                                            const Text('Cuidadores Activos', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                          ],
                                        ),
                                        Text(
                                          '$totalCuidadores',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: Colors.black87),
                  title: const Text('Soporte y Ayuda'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Soporte de CuidaFlow', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text(
                          '¿Tienes dudas, problemas o sugerencias?\n\nEscríbenos a:\nsoporte@cuidaflow.com\n\n¡Estaremos listos para asistirte!',
                          style: TextStyle(height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('¿Estás seguro de que deseas cerrar sesión en CuidaFlow?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context); // Cerrar diálogo
                        await Provider.of<SessionProvider>(context, listen: false).clear();
                        await AuthService().signOut();
                        if (!context.mounted) return;
                        Navigator.pop(context); // Cerrar el Drawer
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'CuidaFlow v1.0.0',
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.uid.isEmpty || session.centroId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: _buildDrawer(context, session),
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('centros').doc(session.centroId).get(),
          builder: (context, snapshot) {
            String nombreCentro = session.getCenterName(session.centroId);
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final String fetchedName = data?['nombre'] ?? session.centroId;
              if (fetchedName != session.centroId && fetchedName != nombreCentro) {
                nombreCentro = fetchedName;
                session.saveCenterName(session.centroId, fetchedName);
              }
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Pacientes del Centro',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white, fontSize: 16),
                ),
                Text(
                  nombreCentro,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (session.isRealAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.activeRole == 'admin' 
                        ? Colors.white.withOpacity(0.18) 
                        : Colors.orangeAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: session.activeRole == 'admin' 
                          ? Colors.white30 
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        session.activeRole == 'admin' 
                            ? Icons.admin_panel_settings 
                            : Icons.visibility_rounded, 
                        size: 14, 
                        color: Colors.white
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.activeRole == 'admin' ? 'Admin' : 'Cuidador',
                        style: const TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: session.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPatientDialog(context),
              backgroundColor: const Color(0xFF00C853),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo Paciente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar paciente...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.blue),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: AppTheme.blue, width: 2)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pacientesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar la información', style: TextStyle(color: Colors.redAccent)));
                }

                final isOffline = snapshot.hasData && snapshot.data!.metadata.isFromCache;
                if (isOffline) {
                  if (_offlineTimer == null && !_showOfflineNotifier.value) {
                    _offlineTimer = Timer(const Duration(seconds: 3), () {
                      _showOfflineNotifier.value = true;
                    });
                  }
                } else {
                  _offlineTimer?.cancel();
                  _offlineTimer = null;
                  if (_showOfflineNotifier.value) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showOfflineNotifier.value = false;
                    });
                  }
                }

                final offlineBanner = Container(
                  width: double.infinity,
                  color: Colors.orange.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text('Modo sin conexión. Datos locales.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );

                final offlineBannerWidget = ValueListenableBuilder<bool>(
                  valueListenable: _showOfflineNotifier,
                  builder: (context, showOffline, child) {
                    if (!showOffline) return const SizedBox.shrink();
                    return offlineBanner;
                  },
                );

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Column(
                    children: [
                      offlineBannerWidget,
                      const Expanded(child: Center(child: Text('No hay pacientes registrados.', style: TextStyle(color: Colors.black54, fontSize: 16)))),
                    ],
                  );
                }

                var docs = snapshot.data!.docs;

                final List<String> currentIds = docs.map((d) => d.id).toList();
                final bool listsAreEqual = _lastSyncedPatientIds != null &&
                    _lastSyncedPatientIds!.length == currentIds.length &&
                    _lastSyncedPatientIds!.every((id) => currentIds.contains(id));

                if (!listsAreEqual) {
                  _lastSyncedPatientIds = currentIds;
                }
                _updateTaskSubscriptions(session.uid, docs);

                if (_searchQuery.isNotEmpty) {
                  String queryNormalized = _removeDiacritics(_searchQuery.toLowerCase());
                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['name'] ?? '';
                    String nameNormalized = _removeDiacritics(name.toLowerCase());
                    return nameNormalized.contains(queryNormalized);
                  }).toList();
                }

                Widget mainContent;
                if (docs.isEmpty) {
                  mainContent = const Expanded(child: Center(child: Text('No se encontraron coincidencias.', style: TextStyle(color: Colors.black54, fontSize: 16))));
                } else {
                  mainContent = Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 80.0),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 15),
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String patientId = doc.id;
                        String initials = data['initials'] ?? '';
                        String name = data['name'] ?? 'Sin nombre';
                        String details = data['details'] ?? '';
                        String status = data['status'] ?? 'Estable';

                        return _buildPatientCard(context, patientId: patientId, initials: initials, name: name, details: details, status: status);
                      },
                    ),
                  );
                }

                return Column(
                  children: [
                    offlineBannerWidget,
                    mainContent,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, {required String patientId, required String initials, required String name, required String details, required String status}) {
    final session = context.read<SessionProvider>();

    Widget card = InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PatientDetailScreen(patientId: patientId, initials: initials, name: name, details: details)),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.blue.withOpacity(0.1),
              child: Text(initials, style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                      const SizedBox(width: 8),
                      if (session.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditPatientDialog(context, patientId, name, details),
                        ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(details, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 12),
                  _buildPatientTaskProgress(patientId),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!session.isAdmin) return card;

    return Dismissible(
      key: Key(patientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('Eliminar Paciente', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('¿Estás seguro de que deseas eliminar a $name? Se borrarán de forma permanente todos sus registros y tareas.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await _dbService.deletePaciente(patientId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paciente $name eliminado con éxito')));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar paciente: $e'), backgroundColor: Colors.red));
        }
      },
      child: card,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String lowerStatus = status.toLowerCase();

    if (lowerStatus == 'estable') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else if (lowerStatus == 'atención' || lowerStatus == 'atencion') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFEF6C00);
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class CenterListTile extends StatelessWidget {
  final String centroId;
  final String activeCentroId;
  final VoidCallback onTap;

  const CenterListTile({
    Key? key,
    required this.centroId,
    required this.activeCentroId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isSelected = centroId == activeCentroId;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('centros').doc(centroId).get(),
      builder: (context, snapshot) {
        String nombreCentro = session.getCenterName(centroId);
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final String fetchedName = data?['nombre'] ?? centroId;
          if (fetchedName != centroId && fetchedName != nombreCentro) {
            nombreCentro = fetchedName;
            // Guardar en cache local para futuras cargas instantáneas
            session.saveCenterName(centroId, fetchedName);
          }
        }
        return ListTile(
          leading: Icon(
            Icons.business_rounded,
            color: isSelected ? AppTheme.green : Colors.black87,
          ),
          title: Text(
            nombreCentro,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.green : Colors.black87,
            ),
          ),
          trailing: isSelected 
              ? const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 20)
              : null,
          onTap: onTap,
        );
      },
    );
  }
}