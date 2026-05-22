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
    // Filtrar cuidadores que aún no están asignados a este día
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

  @override
  Widget build(BuildContext context) {
    final session = SessionService();

    if (session.isAdmin) {
      // Si es administrador, proveemos el TabBar con "Tareas" y "Asignación Semanal"
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppTheme.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white, fontSize: 18)),
                Text(widget.details,
                    style:
                        const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w400)),
              ],
            ),
            backgroundColor: AppTheme.blue,
            elevation: 0,
            bottom: const TabBar(
              labelColor: AppTheme.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppTheme.white,
              indicatorWeight: 3.0,
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_box_outlined),
                        SizedBox(width: 8),
                        Text('Tareas', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined),
                        SizedBox(width: 8),
                        Text('Asignación Semanal', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
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
    } else {
      // Si es cuidador, mostramos la vista simple de tareas (Checklist)
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white, fontSize: 18)),
              Text(widget.details,
                  style: const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w400)),
            ],
          ),
          backgroundColor: AppTheme.blue,
          elevation: 0,
        ),
        body: _buildTasksTab(context, session),
      );
    }
  }

  Widget _buildTasksTab(BuildContext context, SessionService session) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tareas programadas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getPatientTasksStream(widget.patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error al cargar las tareas', style: TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No hay tareas programadas.', style: TextStyle(color: Colors.black54)));
                }

                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var taskDoc = snapshot.data!.docs[index];
                    var taskData = taskDoc.data() as Map<String, dynamic>;

                    String taskId = taskDoc.id;
                    String title = taskData['title'] ?? 'Tarea sin título';
                    String time = taskData['time'] ?? '--:--';
                    bool isCompleted = taskData['isCompleted'] ?? false;

                    return _buildTaskTile(taskId, title, time, isCompleted, session.isAdmin);
                  },
                );
              },
            ),
          ),
          if (session.isAdmin) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _AddTaskModal(patientId: widget.patientId),
                  );
                },
                child: const Text('+ Añadir tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
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

  Widget _buildTaskTile(String taskId, String title, String time, bool isChecked, bool isAdmin) {
    Widget tile = Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: CheckboxListTile(
        value: isChecked,
        // LÓGICA DE BLOQUEO Y TRAZABILIDAD
        onChanged: isAdmin ? null : (bool? newValue) {
          if (newValue != null) {
            String currentUid = SessionService().uid ?? 'UID_NO_ENCONTRADO';
            _dbService.updateTaskStatus(widget.patientId, taskId, newValue, currentUid);
          }
        },
        activeColor: AppTheme.green,
        checkColor: AppTheme.white,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
        subtitle: Text(
          time,
          style: TextStyle(
            color: isChecked ? Colors.grey.shade400 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );

    // Solo los administradores pueden borrar tareas deslizando
    if (!isAdmin) {
      return tile;
    }

    return Dismissible(
      key: Key(taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        _dbService.deleteTask(widget.patientId, taskId);
      },
      child: tile,
    );
  }
}

// Formulario para Tareas
class _AddTaskModal extends StatefulWidget {
  final String patientId;

  const _AddTaskModal({Key? key, required this.patientId}) : super(key: key);

  @override
  State<_AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<_AddTaskModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  void _saveTask() async {
    if (_titleController.text.trim().isEmpty || _timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _dbService.addTask(
        widget.patientId,
        _titleController.text.trim(),
        _timeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agregar tarea',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 30),
            const Text('Nombre de la tarea', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ej: Tomar Aspirina 10mg'),
            ),
            const SizedBox(height: 20),
            const Text('Horario', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _timeController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(hintText: 'Ej: 14:00'),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppTheme.white)
                    : const Text('Guardar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}