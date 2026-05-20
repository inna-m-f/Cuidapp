import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPacientesStream() {
    return _db.collection('pacientes').snapshots();
  }

  Stream<QuerySnapshot> getPatientTasksStream(String patientId) {
    return _db.collection('pacientes').doc(patientId).collection('tareas').snapshots();
  }

  Future<void> updateTaskStatus(String patientId, String taskId, bool isCompleted) async {
    await _db.collection('pacientes').doc(patientId).collection('tareas').doc(taskId).update({
      'isCompleted': isCompleted,
    });
  }

  //insertar una tarea nueva
  Future<void> addTask(String patientId, String title, String time) async {
    await _db.collection('pacientes').doc(patientId).collection('tareas').add({
      'title': title,
      'time': time,
      'isCompleted': false, 
    });
  }
}