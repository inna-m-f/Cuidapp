import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  // Patrón Singleton
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  String? _uid;
  String? _nombre;
  String? _rut;
  String? _rol; // Rol real en el centro activo
  String? _activeRole; // Rol actual renderizado en la UI (puede ser cuidador para un admin)
  String? _centroId; // Centro seleccionado actualmente
  List<String>? _centros; // Lista de centros a los que pertenece
  Map<String, String> _centerNames = {}; // Nombres descriptivos de los centros por centroId
  Map<String, String> _roles = {}; // Roles del usuario por centroId

  // Getters
  String get uid => _uid ?? '';
  String get nombre => _nombre ?? '';
  String get rut => _rut ?? '';
  String get rol => _rol ?? '';
  String get activeRole => _activeRole ?? _rol ?? '';
  String get centroId => _centroId ?? '';
  List<String> get centros => _centros ?? [];
  Map<String, String> get roles => _roles;
  Map<String, String> get centerNames => _centerNames;
  
  bool get isAdmin => activeRole == 'admin';
  bool get isRealAdmin => _rol == 'admin'; // Para saber si tiene permisos para volver a ser admin

  String getCenterName(String cId) {
    return _centerNames[cId] ?? cId;
  }

  Future<void> saveCenterName(String cId, String name) async {
    _centerNames[cId] = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_center_names', jsonEncode(_centerNames));
    } catch (_) {}
  }

  // Inicializar los datos tras un inicio de sesión exitoso
  Future<void> initialize({
    required String uid,
    required String nombre,
    required String rut,
    required String rol,
    required String centroId,
    List<String>? centros,
    Map<String, String>? roles,
  }) async {
    _uid = uid;
    _nombre = nombre;
    _rut = rut;
    _centroId = centroId;
    _centros = centros ?? [centroId];
    _roles = roles ?? {centroId: rol};
    _rol = _roles[centroId] ?? rol;
    _activeRole = _rol;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_uid', uid);
      await prefs.setString('session_nombre', nombre);
      await prefs.setString('session_rut', rut);
      await prefs.setString('session_rol', _rol!);
      await prefs.setString('session_activeRole', _activeRole!);
      await prefs.setString('session_centroId', centroId);
      await prefs.setStringList('session_centros', _centros!);
      await prefs.setString('session_roles', jsonEncode(_roles));
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
    _rol = _roles[newCentroId] ?? 'cuidador';
    _activeRole = _rol;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_centroId', newCentroId);
      await prefs.setString('session_rol', _rol!);
      await prefs.setString('session_activeRole', _activeRole!);
    } catch (e) {}
  }

  // Actualizar centros y roles dinámicamente desde Firestore
  Future<void> updateSessionData({
    required List<String> centros,
    required Map<String, String> roles,
  }) async {
    _centros = centros;
    _roles = roles;

    // Si por alguna razón el centro activo ya no está en la lista de centros,
    // o no estaba inicializado, elegir el primero disponible.
    if (_centroId == null || !centros.contains(_centroId)) {
      if (centros.isNotEmpty) {
        _centroId = centros.first;
        _rol = roles[_centroId!] ?? 'cuidador';
        _activeRole = _rol;
      }
    } else {
      _rol = roles[_centroId!] ?? 'cuidador';
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_centroId != null) {
        await prefs.setString('session_centroId', _centroId!);
      }
      if (_rol != null) {
        await prefs.setString('session_rol', _rol!);
      }
      if (_activeRole != null) {
        await prefs.setString('session_activeRole', _activeRole!);
      }
      await prefs.setStringList('session_centros', _centros!);
      await prefs.setString('session_roles', jsonEncode(_roles));
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
      final rolesStr = prefs.getString('session_roles');

      if (uid != null && nombre != null && rut != null && rol != null && centroId != null) {
        _uid = uid;
        _nombre = nombre;
        _rut = rut;
        _centroId = centroId;
        _centros = centros ?? [centroId];
        
        if (rolesStr != null && rolesStr.isNotEmpty) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(rolesStr);
            _roles = decoded.map((key, value) => MapEntry(key, value.toString()));
          } catch (_) {
            _roles = {centroId: rol};
          }
        } else {
          _roles = {centroId: rol};
        }

        final centerNamesStr = prefs.getString('session_center_names');
        if (centerNamesStr != null && centerNamesStr.isNotEmpty) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(centerNamesStr);
            _centerNames = decoded.map((key, value) => MapEntry(key, value.toString()));
          } catch (_) {}
        }

        _rol = _roles[centroId] ?? rol;
        _activeRole = activeRole ?? _rol;
        return true;
      }
    } catch (e) {}
    return false;
  }

  Future<void> updateNombre(String newName) async {
    _nombre = newName;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_nombre', newName);
    } catch (_) {}
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
    _roles = {};
    _centerNames = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_uid');
      await prefs.remove('session_nombre');
      await prefs.remove('session_rut');
      await prefs.remove('session_rol');
      await prefs.remove('session_activeRole');
      await prefs.remove('session_centroId');
      await prefs.remove('session_centros');
      await prefs.remove('session_roles');
      await prefs.remove('session_center_names');
    } catch (e) {}
  }
}