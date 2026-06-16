import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPacientesStream({
    required String centroId,
    required String rol,
    required String uidCuidador,
    String? diaSemana,
  }) {
    if (rol == 'admin') {
      return _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .snapshots(includeMetadataChanges: true);
    } else {
      final String dia = diaSemana ?? _getDiaSemanaActual();
      final String queryFiltro = '${dia}_$uidCuidador';

      return _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .where('asignaciones', arrayContains: queryFiltro)
          .snapshots(includeMetadataChanges: true);
    }
  }

  String _getDiaSemanaActual() {
    final String dia =
        DateFormat('EEEE', 'es_ES').format(DateTime.now()).toLowerCase();
    return dia
        .replaceAll('miércoles', 'miercoles')
        .replaceAll('sábado', 'sabado');
  }

  String getDiaSemanaActual() {
    return _getDiaSemanaActual();
  }

  String getFechaActualKey() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> addPaciente({
    required String centroId,
    required String name,
    required String details,
    required String initials,
  }) async {
    await _db.collection('pacientes').add({
      'centroId': centroId,
      'name': name,
      'details': details,
      'initials': initials.toUpperCase().trim(),
      'status': 'Estable',
      'progressChips': [],
      'asignaciones': [],
      'fechaIngreso': FieldValue.serverTimestamp(),
      // Campos base Ficha Médica
      'bloodType': '',
      'allergies': '',
      'pathologies': '',
      'emergencyContactName': '',
      'emergencyContactPhone': '',
      'observations': '',
    });
  }

  Future<void> updateMedicalRecord(String patientId, Map<String, dynamic> data) async {
    await _db.collection('pacientes').doc(patientId).update(data);
  }

  Future<void> deletePaciente(String pacienteId) async {
    final QuerySnapshot tasks = await _db
        .collection('pacientes')
        .doc(pacienteId)
        .collection('tareas')
        .get();

    final WriteBatch batch = _db.batch();

    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('pacientes').doc(pacienteId));
    await batch.commit();
  }

  Future<void> asignarCuidadorAPaciente({
    required String pacienteId,
    required String diaSemana,
    required String cuidadorId,
  }) async {
    final String asignacion = '${diaSemana.toLowerCase()}_$cuidadorId';
    await _db.collection('pacientes').doc(pacienteId).update({
      'asignaciones': FieldValue.arrayUnion([asignacion]),
    });
  }

  Future<void> desasignarCuidadorDePaciente({
    required String pacienteId,
    required String diaSemana,
    required String cuidadorId,
  }) async {
    final String asignacion = '${diaSemana.toLowerCase()}_$cuidadorId';
    await _db.collection('pacientes').doc(pacienteId).update({
      'asignaciones': FieldValue.arrayRemove([asignacion]),
    });
  }

  Stream<QuerySnapshot> getCuidadoresStream(String centroId) {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: 'cuidador')
        .where('centros', arrayContains: centroId)
        .snapshots();
  }

  Future<void> registrarCuidador({
    required String rut,
    required String nombre,
    required String centroId,
    required String email,
    required String password,
  }) async {
    final String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();

    final FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'TempRegisterApp',
      options: Firebase.app().options,
    );

    try {
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential credential =
          await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uidNuevoCuidador = credential.user!.uid;

      await _db.collection('usuarios').doc(uidNuevoCuidador).set({
        'rut': cleanRut,
        'nombre': nombre,
        'email': email.trim(),
        'rol': 'cuidador',
        'centros': [centroId], 
        'centroId': centroId, 
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }
  }

  Stream<QuerySnapshot> getPatientTasksStream(String patientId) {
    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .snapshots();
  }

  Stream<QuerySnapshot> getPatientTasksForTodayStream(String patientId) {
    final String diaActual = _getDiaSemanaActual();
    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .where('diasSemana', arrayContains: diaActual)
        .snapshots();
  }

  Future<void> updateTaskStatus(
    String patientId,
    String taskId,
    bool isCompleted,
    String uid,
  ) async {
    final String fechaActual = getFechaActualKey();
    await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .doc(taskId)
        .update({
      'isCompleted': isCompleted,
      'completedBy': isCompleted ? uid : null,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      'completedDates.$fechaActual': isCompleted,
      'completedByDates.$fechaActual': isCompleted ? uid : null,
      'completedAtDates.$fechaActual':
          isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<String> addTask({
    required String patientId,
    required String title,
    required String time,
    required String category,
    required List<String> diasSemana,
  }) async {
    final DocumentReference docRef = await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .add({
      'title': title.trim(),
      'time': time.trim(),
      'category': category.trim(),
      'diasSemana': diasSemana,
      'isCompleted': false,
      'completedBy': null,
      'completedAt': null,
      'completedDates': {},
      'completedByDates': {},
      'completedAtDates': {},
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> deleteTask(String patientId, String taskId) async {
    final DocumentSnapshot doc = await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .doc(taskId)
        .get();

    final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    if (data != null) {
      final String category = (data['category'] ?? '').toString();
      final List<String> diasSemana =
          List<String>.from(data['diasSemana'] ?? []);

      if (category == 'Medicamentos') {
        await NotificationService.cancelMedicationReminder(
          taskId: taskId,
          diasSemana: diasSemana,
        );
      }
    }

    await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .doc(taskId)
        .delete();
  }
}