import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  // Patrón Singleton
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? _uid;
  String? _nombre;
  String? _rut;
  String? _rol;
  String? _centroId;

  // Getters para consultar los datos de la sesión
  String get uid => _uid ?? '';
  String get nombre => _nombre ?? '';
  String get rut => _rut ?? '';
  String get rol => _rol ?? '';
  String get centroId => _centroId ?? '';
  bool get isAdmin => rol == 'admin';

  // Inicializar los datos tras un inicio de sesión exitoso y guardarlos en SharedPreferences
  Future<void> initialize({
    required String uid,
    required String nombre,
    required String rut,
    required String rol,
    required String centroId,
  }) async {
    _uid = uid;
    _nombre = nombre;
    _rut = rut;
    _rol = rol;
    _centroId = centroId;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_uid', uid);
      await prefs.setString('session_nombre', nombre);
      await prefs.setString('session_rut', rut);
      await prefs.setString('session_rol', rol);
      await prefs.setString('session_centroId', centroId);
      await prefs.setString('last_logged_rut', rut);
    } catch (e) {
      // Ignorar errores al guardar en caché local
    }
  }

  // Cargar los datos desde SharedPreferences si existen
  Future<bool> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('session_uid');
      final nombre = prefs.getString('session_nombre');
      final rut = prefs.getString('session_rut');
      final rol = prefs.getString('session_rol');
      final centroId = prefs.getString('session_centroId');

      if (uid != null && nombre != null && rut != null && rol != null && centroId != null) {
        _uid = uid;
        _nombre = nombre;
        _rut = rut;
        _rol = rol;
        _centroId = centroId;
        return true;
      }
    } catch (e) {
      // Ignorar errores al leer caché local
    }
    return false;
  }

  // Limpiar los datos al cerrar sesión y borrarlos de SharedPreferences
  Future<void> clear() async {
    _uid = null;
    _nombre = null;
    _rut = null;
    _rol = null;
    _centroId = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_uid');
      await prefs.remove('session_nombre');
      await prefs.remove('session_rut');
      await prefs.remove('session_rol');
      await prefs.remove('session_centroId');
    } catch (e) {
      // Ignorar errores
    }
  }
}
