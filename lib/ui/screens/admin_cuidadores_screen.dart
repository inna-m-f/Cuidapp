import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/rut_formatter.dart';
import '../../services/database_service.dart';
import '../../providers/session_provider.dart';

class AdminCuidadoresScreen extends StatefulWidget {
  const AdminCuidadoresScreen({Key? key}) : super(key: key);

  @override
  State<AdminCuidadoresScreen> createState() => _AdminCuidadoresScreenState();
}

class _AdminCuidadoresScreenState extends State<AdminCuidadoresScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSaving = false;
  late Stream<QuerySnapshot> _cuidadoresStream;

  @override
  void initState() {
    super.initState();
    final adminCentroId = Provider.of<SessionProvider>(context, listen: false).centroId;
    _cuidadoresStream = _dbService.getCuidadoresStream(adminCentroId);
  }

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
    final TextEditingController rutSearchCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController passwordCtrl = TextEditingController();

    bool hasSearched = false;
    bool userFound = false;
    String foundUserName = '';
    String foundUserId = '';
    bool alreadyInCentro = false;
    bool invitationPending = false;

    showDialog(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Agregar Cuidador',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasSearched) ...[
                      const Text(
                        'Ingresa el RUT para buscar al cuidador en el sistema:',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: rutSearchCtrl,
                        keyboardType: TextInputType.text,
                        inputFormatters: [RutFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'RUT',
                          hintText: 'Ej: 12.345.678-K',
                        ),
                      ),
                    ] else ...[
                      if (userFound) ...[
                        Icon(
                          alreadyInCentro ? Icons.check_circle_outline : Icons.person_outline,
                          size: 60,
                          color: alreadyInCentro ? Colors.green : AppTheme.blue,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          foundUserName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        if (alreadyInCentro)
                          const Text(
                            'Este cuidador ya pertenece a tu centro.',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          )
                        else if (invitationPending)
                          const Text(
                            'Invitación pendiente de aceptación por parte del cuidador.',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          )
                        else
                          const Text(
                            'El cuidador está registrado en la app. ¿Deseas invitarlo a este centro?',
                            textAlign: TextAlign.center,
                          ),
                      ] else ...[
                        const Text(
                          'RUT no registrado. Completa los datos para crear un cuidador nuevo con contraseña temporal:',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 15),
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
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            hintText: 'Ej: juan@correo.com',
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          enabled: !_isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña Temporal',
                            hintText: 'Mínimo 6 caracteres',
                          ),
                        ),
                      ]
                    ],
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
                        onPressed: () {
                          if (hasSearched) {
                            setStateDialog(() {
                              hasSearched = false;
                              userFound = false;
                              alreadyInCentro = false;
                              invitationPending = false;
                            });
                          } else {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: Text(hasSearched ? 'Atrás' : 'Cancelar', style: const TextStyle(color: Colors.grey)),
                      ),
                      if (!hasSearched)
                        ElevatedButton(
                          onPressed: () async {
                            final rut = rutSearchCtrl.text.trim();
                            if (rut.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor ingresa un RUT')),
                              );
                              return;
                            }
                            setStateDialog(() => _isSaving = true);
                            try {
                              final userDoc = await _dbService.findUserByRut(rut);
                              if (userDoc != null && userDoc.exists) {
                                final data = userDoc.data() as Map<String, dynamic>;
                                final String adminCentroId = Provider.of<SessionProvider>(context, listen: false).centroId;
                                final List<String> centros = List<String>.from(data['centros'] ?? []);
                                final List<String> invs = List<String>.from(data['invitaciones'] ?? []);

                                setStateDialog(() {
                                  hasSearched = true;
                                  userFound = true;
                                  foundUserName = data['nombre'] ?? 'Sin nombre';
                                  foundUserId = userDoc.id;
                                  alreadyInCentro = centros.contains(adminCentroId);
                                  invitationPending = invs.contains(adminCentroId);
                                });
                              } else {
                                setStateDialog(() {
                                  hasSearched = true;
                                  userFound = false;
                                });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al buscar: $e')),
                              );
                            } finally {
                              setStateDialog(() => _isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Buscar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      else if (userFound && !alreadyInCentro && !invitationPending)
                        ElevatedButton(
                          onPressed: () async {
                            setStateDialog(() => _isSaving = true);
                            try {
                              final String adminCentroId = Provider.of<SessionProvider>(context, listen: false).centroId;
                              await _dbService.inviteUserToCentro(foundUserId, adminCentroId);
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invitación enviada con éxito'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al enviar invitación: $e'), backgroundColor: Colors.red),
                              );
                            } finally {
                              setStateDialog(() => _isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Enviar Invitación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      else if (!userFound)
                        ElevatedButton(
                          onPressed: () async {
                            final nombre = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            final password = passwordCtrl.text.trim();
                            final rut = rutSearchCtrl.text.trim();

                            if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor completa todos los campos')),
                              );
                              return;
                            }

                            if (password.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
                              );
                              return;
                            }

                            setStateDialog(() => _isSaving = true);
                            try {
                              final String adminCentroId = Provider.of<SessionProvider>(context, listen: false).centroId;
                              await _dbService.registrarCuidador(
                                rut: rut,
                                nombre: nombre,
                                centroId: adminCentroId,
                                email: email,
                                password: password,
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cuidador registrado y asociado con éxito'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al registrar: $e'), backgroundColor: Colors.red),
                              );
                            } finally {
                              setStateDialog(() => _isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
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
    final session = context.watch<SessionProvider>();
    String adminCentroId = session.centroId;

    if (session.uid.isEmpty || adminCentroId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.blue),
        ),
      );
    }

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
        stream: _cuidadoresStream,
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
            List<dynamic> userCentros = data['centros'] ?? [];
            if (!userCentros.contains(adminCentroId)) return false;

            Map<String, dynamic> rolesMap = data['roles'] as Map<String, dynamic>? ?? {};
            String centerRole = rolesMap[adminCentroId] ?? data['rol'] ?? 'cuidador';
            return centerRole == 'cuidador';
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

              List<String> parts = nombre.split(' ');
              String initials = '';
              if (parts.isNotEmpty && parts[0].isNotEmpty) {
                initials += parts[0][0];
              }
              if (parts.length > 1 && parts[1].isNotEmpty) {
                initials += parts[1][0];
              }
              if (initials.isEmpty) initials = 'C';

              final bool isSelf = uid == session.uid;

              return Dismissible(
                key: Key(uid),
                direction: isSelf ? DismissDirection.none : DismissDirection.endToStart,
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
                  if (isSelf) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No puedes darte de baja a ti mismo de este centro.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return false;
                  }
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      title: const Text('Dar de Baja', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Text(
                        '¿Estás seguro de que deseas dar de baja al cuidador $nombre de este centro?\n\nAl hacerlo, ya no podrá gestionar los pacientes ni recibir alertas para este centro.',
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
                    await _dbService.removeUserFromCentro(uid, adminCentroId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cuidador $nombre dado de baja de este centro con éxito')),
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
                    color: isSelf ? Colors.grey.shade50 : AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelf ? Border.all(color: Colors.grey.shade300, width: 1.5) : null,
                    boxShadow: isSelf
                        ? []
                        : [
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
                        backgroundColor: isSelf
                            ? Colors.grey.shade300
                            : AppTheme.blue.withOpacity(0.1),
                        child: Text(
                          initials.toUpperCase(),
                          style: TextStyle(
                            color: isSelf ? Colors.grey.shade600 : AppTheme.blue,
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nombre,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelf ? Colors.grey.shade600 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Tú',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RUT: $rutFormateado',
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelf ? Colors.grey.shade500 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 24),
                      ],
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