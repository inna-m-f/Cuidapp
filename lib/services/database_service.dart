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
      'asignaciones': [],
      'fechaIngreso': FieldValue.serverTimestamp(),
      'bloodType': '',
      'allergies': '',
      'pathologies': '',
      'emergencyContactName': '',
      'emergencyContactPhone': '',
      'observations': '',
    });
  }

  Future<void> updatePacienteData(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('pacientes').doc(patientId).update(data);
  }

  Future<void> updateMedicalRecord(
    String patientId,
    Map<String, dynamic> data,
  ) async {
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
        'roles': {centroId: 'cuidador'},
        'centros': [centroId],
        'centroId': centroId,
        'mustChangePassword': true,
        'invitaciones': [],
        'fechaCreacion': FieldValue.serverTimestamp(),
        'photoUrl': '',
      });

      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }
  }

  Future<DocumentSnapshot?> findUserByRut(String rut) async {
    final String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();

    if (cleanRut.isEmpty) return null;

    final QuerySnapshot result = await _db
        .collection('usuarios')
        .where('rut', isEqualTo: cleanRut)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      return result.docs.first;
    }

    return null;
  }

  Future<void> inviteUserToCentro(String uid, String centroId) async {
    await _db.collection('usuarios').doc(uid).update({
      'invitaciones': FieldValue.arrayUnion([centroId]),
    });
  }

  Future<void> acceptInvitation(String uid, String centroId) async {
    await _db.collection('usuarios').doc(uid).update({
      'centros': FieldValue.arrayUnion([centroId]),
      'centroId': centroId,
      'roles.$centroId': 'cuidador',
      'invitaciones': FieldValue.arrayRemove([centroId]),
    });
  }

  Future<void> rejectInvitation(String uid, String centroId) async {
    await _db.collection('usuarios').doc(uid).update({
      'invitaciones': FieldValue.arrayRemove([centroId]),
    });
  }

  Future<void> removeUserFromCentro(String uid, String centroId) async {
    final DocumentReference docRef = _db.collection('usuarios').doc(uid);

    await _db.runTransaction((transaction) async {
      final DocumentSnapshot snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      final Map<String, dynamic> data =
          snapshot.data() as Map<String, dynamic>;

      final List<String> centros = List<String>.from(data['centros'] ?? []);
      centros.remove(centroId);

      final Map<String, dynamic> roles =
          Map<String, dynamic>.from(data['roles'] ?? {});
      roles.remove(centroId);

      String newActiveCentroId = data['centroId'] ?? '';

      if (newActiveCentroId == centroId) {
        newActiveCentroId = centros.isNotEmpty ? centros.first : '';
      }

      transaction.update(docRef, {
        'centros': centros,
        'roles': roles,
        'centroId': newActiveCentroId,
      });
    });

    try {
      final QuerySnapshot patientsQuery = await _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .get();

      final WriteBatch patientBatch = _db.batch();
      bool hasUpdates = false;

      for (final doc in patientsQuery.docs) {
        final pData = doc.data() as Map<String, dynamic>;
        final List<String> asignaciones =
            List<String>.from(pData['asignaciones'] ?? []);

        final List<String> toRemove =
            asignaciones.where((asig) => asig.endsWith('_$uid')).toList();

        if (toRemove.isNotEmpty) {
          patientBatch.update(doc.reference, {
            'asignaciones': FieldValue.arrayRemove(toRemove),
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await patientBatch.commit();
      }
    } catch (_) {}
  }

  Future<void> updateUserPhoto({
    required String userId,
    required String photoUrl,
  }) async {
    await _db.collection('usuarios').doc(userId).update({
      'photoUrl': photoUrl,
    });
  }

  Future<void> updatePatientPhoto({
    required String patientId,
    required String photoUrl,
  }) async {
    await _db.collection('pacientes').doc(patientId).update({
      'photoUrl': photoUrl,
    });
  }

  Stream<QuerySnapshot> getPatientTasksStream(String patientId) {
    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .snapshots();
  }

  Stream<QuerySnapshot> getPatientTasksForTodayStream(String patientId) {
    return _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
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
    String repeatType = 'weekly_days',
    int? repeatEveryDays,
    DateTime? startDate,
  }) async {
    final docRef = await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .add({
      'title': title,
      'time': time,
      'category': category,
      'diasSemana': diasSemana,
      'repeatType': repeatType,
      'repeatEveryDays': repeatEveryDays,
      'startDate': Timestamp.fromDate(startDate ?? DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> updateTaskData(
    String patientId,
    String taskId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('pacientes')
        .doc(patientId)
        .collection('tareas')
        .doc(taskId)
        .update(data);
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