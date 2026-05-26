import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_service.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential?> signIn(String rut, String password) async {
    try {
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();
      String email = '$cleanRut@cuidapp.com';

      // 1. Iniciar sesión en Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 2. Obtener el perfil del usuario de Firestore
      DocumentSnapshot userDoc = await _db.collection('usuarios').doc(uid).get();
      if (!userDoc.exists) {
        // Si no existe el perfil en la base de datos, cerrar sesión automáticamente
        await signOut();
        throw 'Usuario no registrado en la base de datos de este centro.';
      }

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

      // 3. Inicializar el SessionService con la información obtenida
      await SessionService().initialize(
        uid: uid,
        nombre: data['nombre'] ?? data['name'] ?? '',
        rut: data['rut'] ?? '',
        rol: data['rol'] ?? '',
        centroId: data['centroId'] ?? data['centroID'] ?? '',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Credenciales incorrectas. Verifica tu RUT y Centro.';
      }
      throw e.message ?? 'Error de autenticación de Firebase.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Ocurrió un error inesperado al conectar.';
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await NotificationService.cancelAllReminders();
    await _auth.signOut();
    await SessionService().clear();
  }
}