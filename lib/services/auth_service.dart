import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_service.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      // 1. Iniciar sesión con email real y contraseña individual
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 2. Obtener el perfil del usuario de Firestore
      DocumentSnapshot userDoc = await _db.collection('usuarios').doc(uid).get();
      if (!userDoc.exists) {
        await signOut();
        throw 'Usuario no registrado en la base de datos.';
      }

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

      // 3. Procesar multicentro y retrocompatibilidad
      List<String> centros = [];
      if (data.containsKey('centros')) {
        centros = List<String>.from(data['centros']);
      } else if (data.containsKey('centroId')) {
        centros = [data['centroId']];
      }

      if (centros.isEmpty) {
        await signOut();
        throw 'No tienes centros asignados.';
      }

      // 4. Inicializar el SessionService con la información obtenida
      await SessionService().initialize(
        uid: uid,
        nombre: data['nombre'] ?? data['name'] ?? '',
        rut: data['rut'] ?? '',
        rol: data['rol'] ?? '',
        centroId: centros.first,
        centros: centros,
      );

      return data;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      }
      throw e.message ?? 'Error de autenticación de Firebase.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Ocurrió un error inesperado al conectar.';
    }
  }

  Future<void> signOut() async {
    await NotificationService.cancelAllReminders();
    await _auth.signOut();
    await SessionService().clear();
  }
}