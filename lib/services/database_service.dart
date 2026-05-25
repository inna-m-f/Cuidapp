import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Obtener la lista de pacientes filtrada por Centro y Rol
  Stream<QuerySnapshot> getPacientesStream({
    required String centroId,
    required String rol,
    required String uidCuidador,
    String? diaSemana,
  }) {
    if (rol == 'admin') {
      // El administrador ve todos los pacientes del centro
      return _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .snapshots(includeMetadataChanges: true);
    } else {
      // El cuidador ve únicamente los pacientes que tiene asignados hoy en su centro
      final String dia = diaSemana ?? _getDiaSemanaActual();
      final String queryFiltro = '${dia}_$uidCuidador';

      return _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .where('asignaciones', arrayContains: queryFiltro)
          .snapshots(includeMetadataChanges: true);
    }
  }

  // Método auxiliar para obtener el día de la semana actual en español sin acentos
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

  // Fecha actual para registrar cumplimiento diario
  String getFechaActualKey() {
    final DateTime now = DateTime.now();

    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // 2. Agregar un Paciente nuevo (Exclusivo Admin)
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
    });
  }

  // 3. Eliminar un Paciente y limpiar sus tareas en un lote transaccional (Exclusivo Admin)
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

  // 4. Asignar cuidador a un paciente para un día de la semana (Exclusivo Admin)
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

  // 5. Quitar la asignación de un cuidador para un día de la semana (Exclusivo Admin)
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

  Stream<QuerySnapshot> getCuidadoresStream() {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: 'cuidador')
        .snapshots();
  }

  // 7. Registrar a un nuevo cuidador en Auth y Firestore (Exclusivo Admin)
  Future<void> registrarCuidador({
    required String rut,
    required String nombre,
    required String centroId,
    required String contrasenaCentro,
  }) async {
    final String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();
    final String email = '$cleanRut@cuidapp.com';

    final FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'TempRegisterApp',
      options: Firebase.app().options,
    );

    try {
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final UserCredential credential =
          await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: contrasenaCentro,
      );

      final String uidNuevoCuidador = credential.user!.uid;

      await _db.collection('usuarios').doc(uidNuevoCuidador).set({
        'rut': cleanRut,
        'nombre': nombre,
        'rol': 'cuidador',
        'centroId': centroId,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }
  }

  // 8. Todas las tareas del paciente
  Stream<QuerySnapshot> getPatientTasksStream(String patientId) {
    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .snapshots();
  }

  // 9. Tareas del paciente solo para el día actual
  Stream<QuerySnapshot> getPatientTasksForTodayStream(String patientId) {
    final String diaActual = _getDiaSemanaActual();

    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .where('diasSemana', arrayContains: diaActual)
        .snapshots();
  }

  // 10. Actualización de tarea con trazabilidad diaria
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
      // Se mantiene compatibilidad con la lógica antigua
      'isCompleted': isCompleted,
      'completedBy': isCompleted ? uid : null,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,

      // Nueva lógica diaria
      'completedDates.$fechaActual': isCompleted,
      'completedByDates.$fechaActual': isCompleted ? uid : null,
      'completedAtDates.$fechaActual':
          isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  // 11. Agregar tarea con repetición semanal
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

  final Map<String, dynamic>? data =
      doc.data() as Map<String, dynamic>?;

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