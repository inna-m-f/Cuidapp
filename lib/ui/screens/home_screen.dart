import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    final session = SessionService();
    _pacientesStream = _dbService.getPacientesStream(
      centroId: session.centroId,
      rol: session.rol,
      uidCuidador: session.uid,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final subscription in _taskSubscriptions.values) {
      subscription.cancel();
    }
    _taskSubscriptions.clear();
    super.dispose();
  }

  void _updateTaskSubscriptions(String uidCuidador, List<QueryDocumentSnapshot> patientDocs) {
    final List<String> currentIds = patientDocs.map((d) => d.id).toList();

    // 1. Cancelar suscripciones para pacientes que ya no están asignados
    final keysToRemove = _taskSubscriptions.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in keysToRemove) {
      _taskSubscriptions[id]?.cancel();
      _taskSubscriptions.remove(id);
    }

    // 2. Crear suscripciones para nuevos pacientes
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
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐdÌÍÎÏìíîïÙÚÛÜùúûüÑñÝýÿ';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeoCcDdIIIIiiiiUUUUuuuuNnYyy';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str;
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('medic')) return Icons.medication_rounded;

    if (lower.contains('alimen') ||
        lower.contains('comida') ||
        lower.contains('desayuno') ||
        lower.contains('almuerzo') ||
        lower.contains('colación') ||
        lower.contains('colacion') ||
        lower.contains('once') ||
        lower.contains('cena')) {
      return Icons.restaurant_rounded;
    }

    if (lower.contains('higiene') ||
        lower.contains('aseo') ||
        lower.contains('baño') ||
        lower.contains('bano')) {
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

    if (lower.contains('alimen') ||
        lower.contains('comida') ||
        lower.contains('desayuno') ||
        lower.contains('almuerzo') ||
        lower.contains('colación') ||
        lower.contains('colacion') ||
        lower.contains('once') ||
        lower.contains('cena')) {
      return const Color(0xFF00C853);
    }

    if (lower.contains('higiene') ||
        lower.contains('aseo') ||
        lower.contains('baño') ||
        lower.contains('bano')) {
      return const Color(0xFF2979FF);
    }

    if (lower.contains('salida') || lower.contains('visita')) {
      return const Color(0xFF00A86B);
    }

    return AppTheme.blue;
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

          final category = (data['category'] ??
                  data['categoria'] ??
                  data['tipo'] ??
                  data['type'] ??
                  'Medicamentos')
              .toString();

          grouped.putIfAbsent(category, () {
            return {
              'completed': 0,
              'total': 0,
            };
          });

          grouped[category]!['total'] = grouped[category]!['total']! + 1;

          if (data['isCompleted'] == true) {
            grouped[category]!['completed'] =
                grouped[category]!['completed']! + 1;
          }
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
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isComplete ? color.withOpacity(0.35) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    size: 15,
                    color: color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$completed/$total',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: color,
                    ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Agregar Nuevo Paciente',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    hintText: 'Ej: María González López',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Edad',
                    hintText: 'Ej: 78',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: roomCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Habitación / Ubicación',
                    hintText: 'Ej: Habitación 102',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final age = ageCtrl.text.trim();
                final room = roomCtrl.text.trim();

                if (name.isEmpty || age.isEmpty || room.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor completa todos los campos'),
                    ),
                  );
                  return;
                }

                List<String> parts = name.split(' ');
                String initials = '';

                if (parts.isNotEmpty && parts[0].isNotEmpty) {
                  initials += parts[0][0];
                }

                if (parts.length > 1 && parts[1].isNotEmpty) {
                  initials += parts[1][0];
                }

                if (initials.isEmpty) initials = 'P';

                String details = '$age años • $room';

                try {
                  await _dbService.addPaciente(
                    centroId: SessionService().centroId,
                    name: name,
                    details: details,
                    initials: initials,
                  );

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paciente agregado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Pacientes del Centro',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (session.isAdmin)
            IconButton(
              icon: const Icon(
                Icons.people_alt_outlined,
                color: AppTheme.white,
              ),
              tooltip: 'Gestionar Cuidadores',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminCuidadoresScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppTheme.white,
            ),
            onPressed: () async {
              await AuthService().signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: session.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPatientDialog(context),
              backgroundColor: const Color(0xFF00C853),
              icon: const Icon(
                Icons.add,
                color: Colors.white,
              ),
              label: const Text(
                'Nuevo Paciente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.blue,
                ),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.grey,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(
                    color: AppTheme.blue,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pacientesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.blue),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error al cargar la información',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final isOffline = snapshot.hasData && snapshot.data!.metadata.isFromCache;

                final offlineBanner = Container(
                  width: double.infinity,
                  color: Colors.orange.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Modo sin conexión. Datos cargados de la memoria local.',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Column(
                    children: [
                      if (isOffline) offlineBanner,
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No hay pacientes registrados.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                var docs = snapshot.data!.docs;

                if (session.rol == 'cuidador') {
                  final List<String> currentIds = docs.map((d) => d.id).toList();
                  final bool listsAreEqual = _lastSyncedPatientIds != null &&
                      _lastSyncedPatientIds!.length == currentIds.length &&
                      _lastSyncedPatientIds!.every((id) => currentIds.contains(id));

                  if (!listsAreEqual) {
                    _lastSyncedPatientIds = currentIds;
                  }
                  
                  // Actualizar reactivamente las suscripciones a las tareas de estos pacientes
                  _updateTaskSubscriptions(session.uid, docs);
                }

                if (_searchQuery.isNotEmpty) {
                  String queryNormalized =
                      _removeDiacritics(_searchQuery.toLowerCase());

                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['name'] ?? '';
                    String nameNormalized =
                        _removeDiacritics(name.toLowerCase());

                    return nameNormalized.contains(queryNormalized);
                  }).toList();
                }

                Widget mainContent;
                if (docs.isEmpty) {
                  mainContent = const Expanded(
                    child: Center(
                      child: Text(
                        'No se encontraron coincidencias.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                } else {
                  mainContent = Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        bottom: 80.0,
                      ),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 15),
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String patientId = doc.id;
                        String initials = data['initials'] ?? '';
                        String name = data['name'] ?? 'Sin nombre';
                        String details = data['details'] ?? '';
                        String status = data['status'] ?? 'Estable';

                        return _buildPatientCard(
                          context,
                          patientId: patientId,
                          initials: initials,
                          name: name,
                          details: details,
                          status: status,
                        );
                      },
                    ),
                  );
                }

                return Column(
                  children: [
                    if (isOffline) offlineBanner,
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

  Widget _buildPatientCard(
    BuildContext context, {
    required String patientId,
    required String initials,
    required String name,
    required String details,
    required String status,
  }) {
    final session = SessionService();

    Widget card = InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailScreen(
              patientId: patientId,
              initials: initials,
              name: name,
              details: details,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.blue.withOpacity(0.1),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPatientTaskProgress(patientId),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!session.isAdmin) {
      return card;
    }

    return Dismissible(
      key: Key(patientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              'Eliminar Paciente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              '¿Estás seguro de que deseas eliminar a $name? Se borrarán de forma permanente todos sus registros y tareas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await _dbService.deletePaciente(patientId);

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paciente $name eliminado con éxito'),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar paciente: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}