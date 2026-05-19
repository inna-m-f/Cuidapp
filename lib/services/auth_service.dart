import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signIn(String rut, String password) async {
    try {
      
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '');
      String email = '$cleanRut@cuidapp.com';

      
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Credenciales incorrectas. Verifica tu RUT y Centro.';
      }
      throw e.message ?? 'Error de autenticación de Firebase.';
    } catch (e) {
      throw 'Ocurrió un error inesperado al conectar.';
    }
  }
}