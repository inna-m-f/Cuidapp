import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../core/rut_formatter.dart';
import '../../services/database_service.dart';
import '../../services/session_service.dart';

class AdminCuidadoresScreen extends StatefulWidget {
  const AdminCuidadoresScreen({Key? key}) : super(key: key);

  @override
  State<AdminCuidadoresScreen> createState() => _AdminCuidadoresScreenState();
}

class _AdminCuidadoresScreenState extends State<AdminCuidadoresScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSaving = false;

  // Formatear el RUT para mostrarlo con puntos y guion en la lista
  String _formatRutToShow(String rut) {
    if (rut.length < 2) return rut;
    String clean = rut.replaceAll('.', '').replaceAll('-', '').trim();
    if (clean.isEmpty) return '';
    String dv = clean.substring(clean.length - 1).toUpperCase();
    String digits = clean.substring(0, clean.length - 1);
    if (digits.isEmpty) return dv;

    String formattedDigits = '';
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      formattedDigits = digits[i] + formattedDigits;
      count++;
      if (count == 3 && i > 0) {
        formattedDigits = '.$formattedDigits';
        count = 0;
      }
    }
    return '$formattedDigits-$dv';
  }

  void _showAddCaregiverDialog(BuildContext context) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController rutCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Registrar Cuidador',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        hintText: 'Ej: Juan Pérez',
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: rutCtrl,
                      keyboardType: TextInputType.text,
                      inputFormatters: [RutFormatter()],
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'RUT',
                        hintText: 'Ej: 12.345.678-K',
                      ),
                    ),
                    if (_isSaving) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: AppTheme.blue),
                    ]
                  ],
                ),
              ),
              actions: _isSaving
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final nombre = nameCtrl.text.trim();
                          final rut = rutCtrl.text.trim();

                          if (nombre.isEmpty || rut.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor completa todos los campos')),
                            );
                            return;
                          }

                          setStateDialog(() => _isSaving = true);

                          try {
                            String adminCentroId = SessionService().centroId;

                            // 1. Obtener la contraseña del centro de la colección /centros/{centroId}
                            DocumentSnapshot centroDoc = await FirebaseFirestore.instance
                                .collection('centros')
                                .doc(adminCentroId)
                                .get();

                            if (!centroDoc.exists) {
                              throw 'No se pudo encontrar la información del centro actual.';
                            }

                            Map<String, dynamic> centroData =
                                centroDoc.data() as Map<String, dynamic>;
                            String contrasenaCentro =
                                centroData['nombre'] ?? '';

                            if (contrasenaCentro.isEmpty) {
                              throw 'El centro actual no tiene un nombre configurado.';
                            }

                            // 2. Registrar el cuidador en Firebase Auth y Firestore
                            await _dbService.registrarCuidador(
                              rut: rut,
                              nombre: nombre,
                              centroId: adminCentroId,
                              contrasenaCentro: contrasenaCentro,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cuidador registrado correctamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setStateDialog(() => _isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Registrar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _isSaving = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String adminCentroId = SessionService().centroId;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Gestionar Cuidadores',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white),
        ),
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCaregiverDialog(context),
        backgroundColor: const Color(0xFF00C853),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Agregar Cuidador',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getCuidadoresStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.blue),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error al cargar cuidadores',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  'No hay cuidadores registrados para este centro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            );
          }

          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String cId = data['centroId'] ?? data['centroID'] ?? '';
            return cId == adminCentroId;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  'No hay cuidadores registrados para este centro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 90.0),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String uid = doc.id;
              String nombre = data['nombre'] ?? 'Sin nombre';
              String rut = data['rut'] ?? '';
              String rutFormateado = _formatRutToShow(rut);

              // Generar iniciales del cuidador
              List<String> parts = nombre.split(' ');
              String initials = '';
              if (parts.isNotEmpty && parts[0].isNotEmpty) {
                initials += parts[0][0];
              }
              if (parts.length > 1 && parts[1].isNotEmpty) {
                initials += parts[1][0];
              }
              if (initials.isEmpty) initials = 'C';

              return Dismissible(
                key: Key(uid),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 25.0),
                  child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      title: const Text('Dar de Baja', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text(
                        '¿Estás seguro de que deseas dar de baja al cuidador $nombre?\n\nAl hacerlo, perderá el acceso a la plataforma de inmediato.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Confirmar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) async {
                  try {
                    // Eliminamos el documento del cuidador de la colección /usuarios.
                    // Al no estar registrado en Firestore, el login le bloqueará el acceso automáticamente.
                    await FirebaseFirestore.instance.collection('usuarios').doc(uid).delete();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cuidador $nombre dado de baja con éxito')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppTheme.blue.withOpacity(0.1),
                        child: Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RUT: $rutFormateado',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
