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
      } else if (data.containsKey('centroId') && data['centroId'] != null && data['centroId'].toString().isNotEmpty) {
        centros = [data['centroId']];
      }

      // Procesar mapa de roles por centro
      Map<String, String> rolesMap = {};
      if (data.containsKey('roles') && data['roles'] != null) {
        final Map<String, dynamic> rawRoles = data['roles'] as Map<String, dynamic>;
        rolesMap = rawRoles.map((key, value) => MapEntry(key, value.toString()));
      }

      // Retrocompatibilidad para roles
      if (rolesMap.isEmpty) {
        final String legacyRol = data['rol'] ?? 'cuidador';
        if (centros.isNotEmpty) {
          for (final c in centros) {
            rolesMap[c] = legacyRol;
          }
        } else {
          rolesMap[''] = legacyRol;
        }
      }

      // 4. Inicializar el SessionService con la información obtenida
      await SessionService().initialize(
        uid: uid,
        nombre: data['nombre'] ?? data['name'] ?? '',
        rut: data['rut'] ?? '',
        rol: rolesMap[centros.isNotEmpty ? centros.first : ''] ?? data['rol'] ?? 'cuidador',
        centroId: centros.isNotEmpty ? centros.first : '',
        centros: centros,
        roles: rolesMap,
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