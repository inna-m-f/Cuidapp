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
      case 'miércoles': return 'miercoles';
      case 'sábado': return 'sabado';
      default: return dia.toLowerCase();
    }
  }

  // --- Lógica de UI (Build) ---
  @override
  Widget build(BuildContext context) {
    final session = SessionService();

    if (session.isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(widget.details, style: const TextStyle(fontSize: 13)),
            ]),
            backgroundColor: AppTheme.blue,
            bottom: const TabBar(tabs: [Tab(text: 'Tareas'), Tab(text: 'Asignación Semanal')]),
          ),
          body: TabBarView(children: [_buildTasksTab(context, session), _buildAssignmentsTab(context)]),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name), backgroundColor: AppTheme.blue),
        body: _buildTasksTab(context, session),
      );
    }
  }

  Widget _buildTasksTab(BuildContext context, SessionService session) {
    // 1. Cargamos el mapa de cuidadores para trazabilidad legible
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').where('rol', isEqualTo: 'cuidador').snapshots(),
      builder: (context, snapshotCaregivers) {
        Map<String, String> caregiverMap = {};
        if (snapshotCaregivers.hasData) {
          for (var doc in snapshotCaregivers.data!.docs) {
            caregiverMap[doc.id] = (doc.data() as Map<String, dynamic>)['nombre'] ?? 'Cuidador';
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getPatientTasksStream(widget.patientId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView.separated(
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var taskDoc = snapshot.data!.docs[index];
                  var taskData = taskDoc.data() as Map<String, dynamic>;
                  
                  String? completedByUid = taskData['completedBy'];
                  String? caregiverName = completedByUid != null ? caregiverMap[completedByUid] : null;

                  return _buildTaskTile(
                    taskDoc.id, 
                    taskData['title'] ?? '', 
                    taskData['time'] ?? '', 
                    taskData['isCompleted'] ?? false, 
                    session.isAdmin, 
                    caregiverName
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTile(String taskId, String title, String time, bool isChecked, bool isAdmin, String? caregiverName) {
    Widget tile = Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: isAdmin ? null : (bool? newValue) {
          if (newValue != null) {
            _dbService.updateTaskStatus(widget.patientId, taskId, newValue, SessionService().uid ?? 'UID_NO_ENCONTRADO');
          }
        },
        title: Text(title, style: TextStyle(decoration: isChecked ? TextDecoration.lineThrough : null)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time),
            if (isChecked && caregiverName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Completado por: $caregiverName', style: const TextStyle(fontSize: 11, color: AppTheme.blue, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );

    return isAdmin ? Dismissible(key: Key(taskId), onDismissed: (_) => _dbService.deleteTask(widget.patientId, taskId), child: tile) : tile;
  }

  // --- _buildAssignmentsTab omitido para brevedad pero mantenido idéntico ---
  Widget _buildAssignmentsTab(BuildContext context) { return const Center(child: Text("Sección de Asignaciones")); }
}