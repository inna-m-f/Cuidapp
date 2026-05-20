import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
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
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent,
                    builder: (context) => _AddTaskModal(patientId: patientId),
                  );
                },
                child: const Text('+ Añadir tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

 
  Widget _buildTaskTile(String taskId, String title, String time, bool isChecked) {
    return Dismissible(
      key: Key(taskId),
      direction: DismissDirection.endToStart, // Solo deslizar de derecha a izquierda
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
        // Llamada al servicio de eliminación en Firestore
        _dbService.deleteTask(patientId, taskId);
      },
      child: Container(
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
      ),
    );
  }
}


//Formulario para Tareas
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
            const Text('Agregar tarea', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 30),
            
            const Text('Nombre de la tarea', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
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