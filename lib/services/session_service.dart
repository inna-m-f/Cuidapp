import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  // Patrón Singleton
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? _uid;
  String? _nombre;
  String? _rut;
  String? _rol; // Rol real en base de datos
  String? _activeRole; // Rol actual renderizado en la UI
  String? _centroId; // Centro seleccionado actualmente
  List<String>? _centros; // Lista de centros a los que pertenece

  // Getters
  String get uid => _uid ?? '';
  String get nombre => _nombre ?? '';
  String get rut => _rut ?? '';
  String get rol => _rol ?? '';
  String get activeRole => _activeRole ?? _rol ?? '';
  String get centroId => _centroId ?? '';
  List<String> get centros => _centros ?? [];
  
  bool get isAdmin => activeRole == 'admin';
  bool get isRealAdmin => _rol == 'admin'; // Para saber si tiene permisos para volver a ser admin

  // Inicializar los datos tras un inicio de sesión exitoso
  Future<void> initialize({
    required String uid,
    required String nombre,
    required String rut,
    required String rol,
    required String centroId,
    List<String>? centros,
  }) async {
    _uid = uid;
    _nombre = nombre;
    _rut = rut;
    _rol = rol;
    _activeRole = rol;
    _centroId = centroId;
    _centros = centros ?? [centroId];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_uid', uid);
      await prefs.setString('session_nombre', nombre);
      await prefs.setString('session_rut', rut);
      await prefs.setString('session_rol', rol);
      await prefs.setString('session_activeRole', rol);
      await prefs.setString('session_centroId', centroId);
      await prefs.setStringList('session_centros', _centros!);
      await prefs.setString('last_logged_rut', rut);
    } catch (e) {
      // Ignorar errores caché
    }
  }

  // Cambiar el rol en caliente (Solo válido si es admin real)
  Future<void> setActiveRole(String newRole) async {
    if (_rol != 'admin') return; 
    _activeRole = newRole;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_activeRole', newRole);
    } catch (e) {}
  }

  // Cambiar el centro activo (Para cuidadores multicentro)
  Future<void> setActiveCentro(String newCentroId) async {
    _centroId = newCentroId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_centroId', newCentroId);
    } catch (e) {}
  }

  // Cargar los datos desde SharedPreferences
  Future<bool> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('session_uid');
      final nombre = prefs.getString('session_nombre');
      final rut = prefs.getString('session_rut');
      final rol = prefs.getString('session_rol');
      final activeRole = prefs.getString('session_activeRole');
      final centroId = prefs.getString('session_centroId');
      final centros = prefs.getStringList('session_centros');

      if (uid != null && nombre != null && rut != null && rol != null && centroId != null) {
        _uid = uid;
        _nombre = nombre;
        _rut = rut;
        _rol = rol;
        _activeRole = activeRole ?? rol;
        _centroId = centroId;
        _centros = centros ?? [centroId];
        return true;
      }
    } catch (e) {}
    return false;
  }

  // Limpiar los datos al cerrar sesión
  Future<void> clear() async {
    _uid = null;
    _nombre = null;
    _rut = null;
    _rol = null;
    _activeRole = null;
    _centroId = null;
    _centros = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_uid');
      await prefs.remove('session_nombre');
      await prefs.remove('session_rut');
      await prefs.remove('session_rol');
      await prefs.remove('session_activeRole');
      await prefs.remove('session_centroId');
      await prefs.remove('session_centros');
    } catch (e) {}
  }
}