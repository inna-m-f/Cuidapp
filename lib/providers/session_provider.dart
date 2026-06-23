import 'package:flutter/material.dart';
import '../services/session_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionService _sessionService = SessionService();

  // Getters delegation
  String get uid => _sessionService.uid;
  String get nombre => _sessionService.nombre;
  String get rut => _sessionService.rut;
  String get rol => _sessionService.rol;
  String get activeRole => _sessionService.activeRole;
  String get centroId => _sessionService.centroId;
  List<String> get centros => _sessionService.centros;
  Map<String, String> get roles => _sessionService.roles;
  Map<String, String> get centerNames => _sessionService.centerNames;
  
  bool get isAdmin => _sessionService.isAdmin;
  bool get isRealAdmin => _sessionService.isRealAdmin;

  String getCenterName(String cId) => _sessionService.getCenterName(cId);

  // Reactive state changers
  Future<void> initialize({
    required String uid,
    required String nombre,
    required String rut,
    required String rol,
    required String centroId,
    List<String>? centros,
    Map<String, String>? roles,
  }) async {
    await _sessionService.initialize(
      uid: uid,
      nombre: nombre,
      rut: rut,
      rol: rol,
      centroId: centroId,
      centros: centros,
      roles: roles,
    );
    notifyListeners();
  }

  Future<void> setActiveRole(String newRole) async {
    await _sessionService.setActiveRole(newRole);
    notifyListeners();
  }

  Future<void> setActiveCentro(String newCentroId) async {
    await _sessionService.setActiveCentro(newCentroId);
    notifyListeners();
  }

  Future<void> updateSessionData({
    required List<String> centros,
    required Map<String, String> roles,
  }) async {
    await _sessionService.updateSessionData(centros: centros, roles: roles);
    notifyListeners();
  }

  Future<void> saveCenterName(String cId, String name) async {
    await _sessionService.saveCenterName(cId, name);
    notifyListeners();
  }

  Future<bool> loadSession() async {
    final success = await _sessionService.loadSession();
    if (success) {
      notifyListeners();
    }
    return success;
  }

  Future<void> updateNombre(String newName) async {
    await _sessionService.updateNombre(newName);
    notifyListeners();
  }

  Future<void> clear() async {
    await _sessionService.clear();
    notifyListeners();
  }
}
