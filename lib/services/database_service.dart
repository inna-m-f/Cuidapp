import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtenemos un flujo constante (Stream) de la colección de pacientes
  Stream<QuerySnapshot> getPacientesStream() {
    return _db.collection('pacientes').snapshots();
  }
}