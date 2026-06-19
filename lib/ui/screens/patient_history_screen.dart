import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../providers/session_provider.dart';

class PatientHistoryScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientHistoryScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  late Stream<QuerySnapshot> _tasksStream;
  late Stream<QuerySnapshot> _caregiversStream;

  late DateTime _monday;
  late DateTime _sunday;
  late List<String> _currentWeekKeys;

  @override
  void initState() {
    super.initState();
    _calculateCurrentWeek();
    _tasksStream = _dbService.getPatientTasksStream(widget.patientId);
    final centroId = Provider.of<SessionProvider>(context, listen: false).centroId;
    _caregiversStream = _dbService.getCuidadoresStream(centroId);
  }

  void _calculateCurrentWeek() {
    final DateTime now = DateTime.now();
    // En Dart, DateTime.weekday retorna 1 para Lunes y 7 para Domingo.
    _monday = now.subtract(Duration(days: now.weekday - 1));
    _sunday = _monday.add(const Duration(days: 6));

    // Generar las llaves YYYY-MM-DD de la semana en curso
    _currentWeekKeys = List.generate(7, (index) {
      final date = _monday.add(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(date);
    });
  }

  String _formatFechaHumana(String dateKey) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateKey);
      const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      final diaStr = dias[date.weekday - 1];
      final dateStr = DateFormat('dd/MM').format(date);
      return '$diaStr $dateStr';
    } catch (e) {
      return dateKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String startStr = DateFormat('dd/MM/yyyy').format(_monday);
    final String endStr = DateFormat('dd/MM/yyyy').format(_sunday);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial Semanal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text(widget.patientName, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: AppTheme.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Semana del $startStr al $endStr',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.blue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildWeeklyReport()),
        ],
      ),
    );
  }

  Widget _buildWeeklyReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: _caregiversStream,
      builder: (context, caregiversSnapshot) {
        if (!caregiversSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
        }

        final Map<String, String> caregiverMap = {};
        for (final doc in caregiversSnapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          caregiverMap[doc.id] = data['nombre'] ?? 'Cuidador desconocido';
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _tasksStream,
          builder: (context, tasksSnapshot) {
            if (tasksSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
            }

            if (!tasksSnapshot.hasData || tasksSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay registro de tareas.'));
            }

            // Agrupar tareas por Cuidador
            final Map<String, List<Map<String, dynamic>>> tasksByCaregiver = {};
            int totalCompletedThisWeek = 0;

            for (final doc in tasksSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              
              final completedMap = data['completedDates'] as Map<String, dynamic>? ?? {};
              final byMap = data['completedByDates'] as Map<String, dynamic>? ?? {};
              final atMap = data['completedAtDates'] as Map<String, dynamic>? ?? {};

              // Revisar cada día de la semana actual
              for (final dateKey in _currentWeekKeys) {
                if (completedMap[dateKey] == true) {
                  final uid = byMap[dateKey]?.toString() ?? 'unknown';
                  
                  tasksByCaregiver.putIfAbsent(uid, () => []);
                  tasksByCaregiver[uid]!.add({
                    'title': data['title'] ?? 'Tarea sin nombre',
                    'scheduledTime': data['time'] ?? '--:--',
                    'dateKey': dateKey,
                    'completedAt': atMap[dateKey] as Timestamp?,
                  });
                  totalCompletedThisWeek++;
                }
              }
            }

            if (tasksByCaregiver.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade400),
                    const SizedBox(height: 15),
                    const Text('No se han registrado tareas\nen la semana en curso.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              );
            }

            final uids = tasksByCaregiver.keys.toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Total semana: $totalCompletedThisWeek tareas realizadas',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 15),
                ...uids.map((uid) {
                  final tasks = tasksByCaregiver[uid]!;
                  final caregiverName = caregiverMap[uid] ?? (uid == 'unknown' ? 'Registro perdido' : 'Cuidador eliminado');
                  
                  // Ordenar las tareas del cuidador por fecha
                  tasks.sort((a, b) => a['dateKey'].compareTo(b['dateKey']));

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    shadowColor: Colors.black12,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.green.withOpacity(0.15),
                          child: const Icon(Icons.person, color: AppTheme.green),
                        ),
                        title: Text(caregiverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('${tasks.length} tareas completadas', style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.w600)),
                        children: tasks.map((taskData) {
                          final Timestamp? ts = taskData['completedAt'];
                          final String regTime = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '--:--';
                          
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.check_circle, color: AppTheme.green, size: 20),
                              title: Text(taskData['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                'Día: ${_formatFechaHumana(taskData['dateKey'])} • Programado: ${taskData['scheduledTime']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Registrado', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(regTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }
}