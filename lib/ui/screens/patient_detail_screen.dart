import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../services/session_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String initials;
  final String name;
  final String details;

  const PatientDetailScreen({
    Key? key,
    required this.patientId,
    required this.initials,
    required this.name,
    required this.details,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final DatabaseService _dbService = DatabaseService();

  String _normalizeDia(String dia) {
    switch (dia.toLowerCase()) {
      case 'miércoles':
        return 'miercoles';
      case 'sábado':
        return 'sabado';
      default:
        return dia.toLowerCase();
    }
  }

  void _showAssignCaregiverDialog({
    required BuildContext context,
    required String dia,
    required List<String> alreadyAssignedUids,
    required List<QueryDocumentSnapshot> allCaregivers,
  }) {
    final unassigned = allCaregivers.where((doc) => !alreadyAssignedUids.contains(doc.id)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Asignar Cuidador - $dia',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: unassigned.isEmpty
              ? const Text(
                  'Todos los cuidadores disponibles ya están asignados a este día.',
                  style: TextStyle(color: Colors.black54),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: unassigned.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      var doc = unassigned[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String uid = doc.id;
                      String nombre = data['nombre'] ?? 'Sin nombre';
                      String rut = data['rut'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.blue.withOpacity(0.1),
                          child: Text(
                            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                            style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('RUT: $rut'),
                        trailing: const Icon(Icons.add_circle_outline, color: AppTheme.blue),
                        onTap: () async {
                          try {
                            await _dbService.asignarCuidadorAPaciente(
                              pacienteId: widget.patientId,
                              cuidadorId: uid,
                              diaSemana: _normalizeDia(dia),
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$nombre asignado correctamente para el día $dia'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';

    if (raw.isEmpty) return '';

    final clean = raw.replaceAll(':', '').replaceAll(' ', '');

    if (clean.length == 4 && int.tryParse(clean) != null) {
      return '${clean.substring(0, 2)}:${clean.substring(2, 4)}';
    }

    if (clean.length == 3 && int.tryParse(clean) != null) {
      return '0${clean.substring(0, 1)}:${clean.substring(1, 3)}';
    }

    return raw;
  }

  String _getCategory(Map<String, dynamic> data) {
    final rawCategory = data['category'] ??
        data['categoria'] ??
        data['tipo'] ??
        data['type'] ??
        '';

    final category = rawCategory.toString().trim();

    if (category.isEmpty) {
      return 'Medicamentos';
    }

    return category;
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('medic')) return Icons.medication_rounded;

    if (lower.contains('alimen') ||
        lower.contains('comida') ||
        lower.contains('desayuno') ||
        lower.contains('almuerzo') ||
        lower.contains('cena')) {
      return Icons.restaurant_rounded;
    }

    if (lower.contains('higiene') ||
        lower.contains('aseo') ||
        lower.contains('baño')) {
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
        lower.contains('cena')) {
      return const Color(0xFF00C853);
    }

    if (lower.contains('higiene') ||
        lower.contains('aseo') ||
        lower.contains('baño')) {
      return const Color(0xFF2979FF);
    }

    if (lower.contains('salida') || lower.contains('visita')) {
      return const Color(0xFF00A86B);
    }

    return AppTheme.blue;
  }

  Map<String, List<QueryDocumentSnapshot>> _groupTasksByCategory(
    List<QueryDocumentSnapshot> docs,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = _getCategory(data);

      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(doc);
    }

    grouped.forEach((category, tasks) {
      tasks.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;

        final timeA = _formatTime(dataA['time']);
        final timeB = _formatTime(dataB['time']);

        return timeA.compareTo(timeB);
      });
    });

    return grouped;
  }

  void _showAddTaskDialog() {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController timeCtrl = TextEditingController();

    String selectedCategory = 'Medicamentos';

    final List<String> categories = [
      'Medicamentos',
      'Alimentación',
      'Higiene',
      'Salidas / Visitas',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Agregar tarea',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 20,
                                  color: _getCategoryColor(category),
                                ),
                                const SizedBox(width: 10),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            selectedCategory = value;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Nombre de la tarea',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: selectedCategory == 'Medicamentos'
                              ? 'Ej: Metformina 500mg'
                              : selectedCategory == 'Alimentación'
                                  ? 'Ej: Almuerzo'
                                  : selectedCategory == 'Higiene'
                                      ? 'Ej: Baño'
                                      : 'Ej: Visita familiar',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Horario',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: timeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Ej: 0800',
                          helperText: 'Ingrese 4 números. Ejemplo: 0800 → 08:00',
                          suffixIcon: const Icon(Icons.schedule),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            final rawTime = timeCtrl.text.trim();

                            if (title.isEmpty || rawTime.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Completa el nombre y horario de la tarea',
                                  ),
                                ),
                              );
                              return;
                            }

                            final cleanTime = rawTime.replaceAll(':', '').trim();

                            if (int.tryParse(cleanTime) == null ||
                                cleanTime.length < 3 ||
                                cleanTime.length > 4) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ingrese un horario válido. Ejemplo: 0800 o 1400',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            final formattedTime = _formatTime(rawTime);

                            await _dbService.addTask(
                              patientId: widget.patientId,
                              title: title,
                              time: formattedTime,
                              category: selectedCategory,
                            );

                            if (!context.mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tarea agregada correctamente'),
                                backgroundColor: Color(0xFF00C853),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Guardar tarea',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService();

    if (session.isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            backgroundColor: AppTheme.blue,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.details,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            bottom: const TabBar(
              indicatorColor: Color(0xFF00C853),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Tareas'),
                Tab(text: 'Asignación Semanal'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildTasksTab(context, session),
              _buildAssignmentsTab(context),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              widget.details,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: _buildTasksTab(context, session),
    );
  }

  Widget _buildTasksTab(BuildContext context, SessionService session) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'cuidador')
          .snapshots(),
      builder: (context, snapshotCaregivers) {
        final Map<String, String> caregiverMap = {};

        if (snapshotCaregivers.hasData) {
          for (final doc in snapshotCaregivers.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            caregiverMap[doc.id] = data['nombre'] ?? 'Cuidador';
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getPatientTasksStream(widget.patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.blue),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Error al cargar las tareas',
                  style: TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  const Text(
                    'Tareas por categoría',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Registro diario de cuidados realizados al paciente.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay tareas registradas',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Agregue medicamentos, higiene, alimentación u otras tareas de cuidado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildAddTaskButton(),
                ],
              );
            }

            final groupedTasks = _groupTasksByCategory(docs);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                const Text(
                  'Tareas por categoría',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Registro diario de cuidados realizados al paciente.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),

                ...groupedTasks.entries.map((entry) {
                  final category = entry.key;
                  final tasks = entry.value;
                  final completed = tasks.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isCompleted'] == true;
                  }).length;

                  return _buildCategoryCard(
                    category: category,
                    completed: completed,
                    total: tasks.length,
                    tasks: tasks,
                    caregiverMap: caregiverMap,
                    session: session,
                  );
                }).toList(),

                const SizedBox(height: 8),
                _buildAddTaskButton(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddTaskButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Añadir tarea',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
  required String category,
  required int completed,
  required int total,
  required List<QueryDocumentSnapshot> tasks,
  required Map<String, String> caregiverMap,
  required SessionService session,
}) {
  final color = _getCategoryColor(category);

  final pendingTasks = tasks.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return data['isCompleted'] != true;
  }).toList();

  final completedTasks = tasks.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return data['isCompleted'] == true;
  }).toList();

  return Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  _getCategoryIcon(category),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '$completed/$total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        if (pendingTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade400,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Todas las tareas de esta categoría están completadas.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingTasks.map((taskDoc) {
            final data = taskDoc.data() as Map<String, dynamic>;

            final completedByUid = data['completedBy'];
            final caregiverName =
                completedByUid != null ? caregiverMap[completedByUid] : null;

            return _buildTaskRow(
              taskId: taskDoc.id,
              title: data['title'] ?? '',
              time: _formatTime(data['time']),
              isChecked: data['isCompleted'] ?? false,
              isAdmin: session.isAdmin,
              caregiverName: caregiverName,
              color: color,
            );
          }).toList(),

        if (completedTasks.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18),
              childrenPadding: const EdgeInsets.only(bottom: 10),
              leading: Icon(
                Icons.done_all_rounded,
                color: Colors.green.shade600,
              ),
              title: Text(
                'Tareas completadas ($completed)',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              subtitle: const Text(
                'Toca para ver o desmarcar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
              children: completedTasks.map((taskDoc) {
                final data = taskDoc.data() as Map<String, dynamic>;

                final completedByUid = data['completedBy'];
                final caregiverName =
                    completedByUid != null ? caregiverMap[completedByUid] : null;

                return _buildTaskRow(
                  taskId: taskDoc.id,
                  title: data['title'] ?? '',
                  time: _formatTime(data['time']),
                  isChecked: data['isCompleted'] ?? false,
                  isAdmin: session.isAdmin,
                  caregiverName: caregiverName,
                  color: color,
                );
              }).toList(),
            ),
          ),
      ],
    ),
  );
}
  Widget _buildTaskRow({
    required String taskId,
    required String title,
    required String time,
    required bool isChecked,
    required bool isAdmin,
    required String? caregiverName,
    required Color color,
  }) {
    final row = InkWell(
      onTap: isAdmin
          ? null
          : () {
              _dbService.updateTaskStatus(
                widget.patientId,
                taskId,
                !isChecked,
                SessionService().uid ?? 'UID_NO_ENCONTRADO',
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? const Color(0xFF00C853) : Colors.white,
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF00C853)
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Tarea sin nombre' : title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationThickness: 2,
                    ),
                  ),
                  if (isChecked && caregiverName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completado por: $caregiverName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            Text(
              time,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    if (!isAdmin) return row;

    return Dismissible(
      key: Key(taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Eliminar tarea',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text('¿Deseas eliminar la tarea "$title"?'),
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
                ),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        _dbService.deleteTask(widget.patientId, taskId);
      },
      child: row,
    );
  }

  Widget _buildAssignmentsTab(BuildContext context) {
    final String adminCentroId = SessionService().centroId;
    final List<String> dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getCuidadoresStream(),
      builder: (context, caregiversSnapshot) {
        if (caregiversSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
        }

        if (caregiversSnapshot.hasError) {
          return const Center(child: Text('Error al obtener la lista de cuidadores.'));
        }

        // Crear mapa uid -> nombre para buscar rápido
        Map<String, String> caregiverNames = {};
        List<QueryDocumentSnapshot> caregiversDocs = [];
        if (caregiversSnapshot.hasData) {
          caregiversDocs = caregiversSnapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String cId = data['centroId'] ?? data['centroID'] ?? '';
            return cId == adminCentroId;
          }).toList();

          for (var doc in caregiversDocs) {
            caregiverNames[doc.id] = (doc.data() as Map<String, dynamic>)['nombre'] ?? 'Sin nombre';
          }
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).snapshots(),
          builder: (context, patientSnapshot) {
            if (patientSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
            }

            if (!patientSnapshot.hasData || !patientSnapshot.data!.exists) {
              return const Center(child: Text('No se pudo cargar la información del paciente.'));
            }

            var patientData = patientSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            List<String> asignaciones = List<String>.from(patientData['asignaciones'] ?? []);

            return ListView.separated(
              padding: const EdgeInsets.all(20.0),
              itemCount: dias.length,
              separatorBuilder: (context, index) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                String dia = dias[index];
                String normalizedDia = _normalizeDia(dia);
                String prefix = '${normalizedDia}_';

                // Filtrar uids asignados a este día específico
                List<String> assignedUids = asignaciones
                    .where((asig) => asig.startsWith(prefix))
                    .map((asig) => asig.substring(prefix.length))
                    .toList();

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dia,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.blue, size: 24),
                            onPressed: () {
                              _showAssignCaregiverDialog(
                                context: context,
                                dia: dia,
                                alreadyAssignedUids: assignedUids,
                                allCaregivers: caregiversDocs,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      assignedUids.isEmpty
                          ? const Text(
                              'Sin cuidadores asignados',
                              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: assignedUids.map((uid) {
                                String nombreCuidador = caregiverNames[uid] ?? 'Cargando...';
                                return Chip(
                                  backgroundColor: AppTheme.blue.withOpacity(0.08),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  label: Text(
                                    nombreCuidador,
                                    style: const TextStyle(
                                      color: AppTheme.blue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  deleteIcon: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
                                  onDeleted: () async {
                                    try {
                                      await _dbService.desasignarCuidadorDePaciente(
                                        pacienteId: widget.patientId,
                                        cuidadorId: uid,
                                        diaSemana: normalizedDia,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Se quitó a $nombreCuidador de la asignación del $dia'),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}