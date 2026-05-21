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

  // Inicializar los datos tras un inicio de sesión exitoso
  void initialize({
    required String uid,
    required String nombre,
    required String rut,
    required String rol,
    required String centroId,
  }) {
    _uid = uid;
    _nombre = nombre;
    _rut = rut;
    _rol = rol;
    _centroId = centroId;
  }

  // Limpiar los datos al cerrar sesión
  void clear() {
    _uid = null;
    _nombre = null;
    _rut = null;
    _rol = null;
    _centroId = null;
  }
}
