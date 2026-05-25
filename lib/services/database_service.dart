import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
      String dia = diaSemana ?? _getDiaSemanaActual();
      String queryFiltro = '${dia}_$uidCuidador';
      return _db
          .collection('pacientes')
          .where('centroId', isEqualTo: centroId)
          .where('asignaciones', arrayContains: queryFiltro)
          .snapshots(includeMetadataChanges: true);
    }
  }

  // Método auxiliar para obtener el día de la semana actual en español sin acentos
  String _getDiaSemanaActual() {
    final String dia = DateFormat('EEEE', 'es_ES').format(DateTime.now()).toLowerCase();
    return dia.replaceAll('miércoles', 'miercoles').replaceAll('sábado', 'sabado');
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
    // Obtener las tareas del paciente
    QuerySnapshot tasks = await _db
        .collection('pacientes')
        .doc(pacienteId)
        .collection('tareas')
        .get();

    WriteBatch batch = _db.batch();

    // Eliminar todas las tareas del paciente
    for (var doc in tasks.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar el documento del paciente
    batch.delete(_db.collection('pacientes').doc(pacienteId));

    // Comprometer lote en Firestore
    await batch.commit();
  }

  // 4. Asignar cuidador a un paciente para un día de la semana (Exclusivo Admin)
  Future<void> asignarCuidadorAPaciente({
    required String pacienteId,
    required String diaSemana,
    required String cuidadorId,
  }) async {
    String asignacion = '${diaSemana.toLowerCase()}_$cuidadorId';
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
    String asignacion = '${diaSemana.toLowerCase()}_$cuidadorId';
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
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();
    String email = '$cleanRut@cuidapp.com';

    // Creamos una FirebaseApp secundaria temporal para no desloguear al Admin
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'TempRegisterApp',
      options: Firebase.app().options,
    );

    try {
      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      UserCredential credential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: contrasenaCentro,
      );

      String uidNuevoCuidador = credential.user!.uid;

      // Guardamos la info del nuevo cuidador en Firestore usando la app principal
      await _db.collection('usuarios').doc(uidNuevoCuidador).set({
        'rut': cleanRut,
        'nombre': nombre,
        'rol': 'cuidador',
        'centroId': centroId,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      await tempAuth.signOut();
    } finally {
      // Destruimos la app temporal
      await tempApp.delete();
    }
  }

  // 8. Tareas del paciente (Subcolección)
  Stream<QuerySnapshot> getPatientTasksStream(String patientId) {
    return _db.collection('pacientes').doc(patientId).collection('tareas').snapshots();
  }

  // RF-09: Actualización de tarea con trazabilidad (Agregado parámetro 'uid')
  Future<void> updateTaskStatus(String patientId, String taskId, bool isCompleted, String uid) async {
    await _db.collection('pacientes').doc(patientId).collection('tareas').doc(taskId).update({
      'isCompleted': isCompleted,
      'completedBy': isCompleted ? uid : null,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

Future<void> addTask({
  required String patientId,
  required String title,
  required String time,
  required String category,
}) async {
  await _db.collection('pacientes').doc(patientId).collection('tareas').add({
    'title': title.trim(),
    'time': time.trim(),
    'category': category.trim(),
    'isCompleted': false,
    'completedBy': null,
    'completedAt': null,
    'fechaCreacion': FieldValue.serverTimestamp(),
  });
}

  Future<void> deleteTask(String patientId, String taskId) async {
    await _db.collection('pacientes').doc(patientId).collection('tareas').doc(taskId).delete();
  }
}