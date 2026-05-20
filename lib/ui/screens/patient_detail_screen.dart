import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId; // <-- Recibimos el ID
  final String initials;
  final String name;
  final String details;

  PatientDetailScreen({
    Key? key,
    required this.patientId,
    required this.initials,
    required this.name,
    required this.details,
  }) : super(key: key);

  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
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
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white, fontSize: 18)),
            Text(details, style: const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppTheme.blue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tareas programadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            
            // Lista de Tareas Reactiva
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _dbService.getPatientTasksStream(patientId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error al cargar las tareas', style: TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay tareas programadas.', style: TextStyle(color: Colors.black54)));
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

                      return _buildTaskTile(taskId, title, time, isCompleted);
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Lógica para agregar tarea (Próximo hito)
                },
                child: const Text('+ Añadir tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Componente de tarea actualizado para interactuar directamente con Firestore
  Widget _buildTaskTile(String taskId, String title, String time, bool isChecked) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (bool? newValue) {
          if (newValue != null) {
            // Actualización directa a la base de datos
            _dbService.updateTaskStatus(patientId, taskId, newValue);
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
  }
}