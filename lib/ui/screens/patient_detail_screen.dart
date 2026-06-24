import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../providers/session_provider.dart';
import '../../services/image_helper.dart';
import 'patient_history_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String initials;
  final String name;
  final String details;

  const PatientDetailScreen({
    Key? key,
    required this.patientId,
    required this.initials,
    required this.name,
    required this.details,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
  }

  String _normalizeDia(String dia) {
    switch (dia.toLowerCase()) {
      case 'miércoles':
        return 'miercoles';
      case 'sábado':
        return 'sabado';
      default:
        return dia.toLowerCase();
    }
  }

  void _showAssignCaregiverDialog({
    required BuildContext context,
    required String dia,
    required List<String> alreadyAssignedUids,
    required List<QueryDocumentSnapshot> allCaregivers,
  }) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final String adminUid = session.uid;
    
    final bool canAssignSelf = !alreadyAssignedUids.contains(adminUid);

    final unassigned = allCaregivers
        .where((doc) => !alreadyAssignedUids.contains(doc.id) && doc.id != adminUid)
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Asignar Cuidador - $dia',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: (unassigned.isEmpty && !canAssignSelf)
              ? const Text(
                  'Todos los cuidadores (incluyéndote) ya están asignados a este día.',
                  style: TextStyle(color: Colors.black54),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canAssignSelf) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.green.withOpacity(0.15),
                            child: const Icon(Icons.admin_panel_settings, color: AppTheme.green, size: 22),
                          ),
                          title: const Text('Asignarme a mí', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.green)),
                          subtitle: const Text('Asumir labores de cuidador', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.add_circle, color: AppTheme.green),
                          onTap: () async {
                            try {
                              await _dbService.asignarCuidadorAPaciente(
                                pacienteId: widget.patientId,
                                cuidadorId: adminUid,
                                diaSemana: _normalizeDia(dia),
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Te has autoasignado para el día $dia'), backgroundColor: Colors.green));
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          },
                        ),
                        if (unassigned.isNotEmpty) const Divider(height: 20),
                      ],

                      if (unassigned.isNotEmpty)
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: unassigned.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final doc = unassigned[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final String uid = doc.id;
                              final String nombre = data['nombre'] ?? 'Sin nombre';
                              final String rut = data['rut'] ?? '';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.blue.withOpacity(0.1),
                                  child: Text(
                                    nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C',
                                    style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('RUT: $rut'),
                                trailing: const Icon(Icons.add_circle_outline, color: AppTheme.blue),
                                onTap: () async {
                                  try {
                                    await _dbService.asignarCuidadorAPaciente(
                                      pacienteId: widget.patientId,
                                      cuidadorId: uid,
                                      diaSemana: _normalizeDia(dia),
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre asignado correctamente para el día $dia'), backgroundColor: Colors.green));
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                  }
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';

    final upper = raw.toUpperCase();
    final amPmRegex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final match = amPmRegex.firstMatch(upper);

    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = match.group(2)!;
      final period = match.group(3)!;
      return '$hour:$minute $period';
    }

    final clean = raw.replaceAll(':', '').replaceAll(' ', '');
    if (clean.length == 4 && int.tryParse(clean) != null) {
      return '${clean.substring(0, 2)}:${clean.substring(2, 4)}';
    }
    if (clean.length == 3 && int.tryParse(clean) != null) {
      return '0${clean.substring(0, 1)}:${clean.substring(1, 3)}';
    }
    return raw;
  }

  int _timeToMinutes(dynamic value) {
    final raw = value?.toString().trim().toUpperCase() ?? '';
    if (raw.isEmpty) return 99999;

    final amPmRegex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final match = amPmRegex.firstMatch(raw);

    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!;

      if (period == 'AM') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }
      return hour * 60 + minute;
    }

    final clean = raw.replaceAll(':', '').replaceAll(' ', '');
    if (clean.length == 4 && int.tryParse(clean) != null) {
      final hour = int.parse(clean.substring(0, 2));
      final minute = int.parse(clean.substring(2, 4));
      return hour * 60 + minute;
    }
    if (clean.length == 3 && int.tryParse(clean) != null) {
      final hour = int.parse(clean.substring(0, 1));
      final minute = int.parse(clean.substring(1, 3));
      return hour * 60 + minute;
    }
    return 99999;
  }

  bool _isCompletedToday(Map<String, dynamic> data) {
    final fechaActual = _dbService.getFechaActualKey();
    final completedDates = data['completedDates'];

    if (completedDates is Map<String, dynamic>) {
      return completedDates[fechaActual] == true;
    }
    return false;
  }

  String _getDiaSemanaActual() {
    final int weekday = DateTime.now().weekday;
    switch (weekday) {
      case DateTime.monday: return 'lunes';
      case DateTime.tuesday: return 'martes';
      case DateTime.wednesday: return 'miercoles';
      case DateTime.thursday: return 'jueves';
      case DateTime.friday: return 'viernes';
      case DateTime.saturday: return 'sabado';
      case DateTime.sunday: return 'domingo';
      default: return 'lunes';
    }
  }


 bool _isTaskScheduledForToday(Map<String, dynamic> data) {
  final String repeatType = data['repeatType']?.toString() ?? 'weekly_days';

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);

  DateTime startDate = today;
  final rawStartDate = data['startDate'];

  if (rawStartDate is Timestamp) {
    final parsed = rawStartDate.toDate();
    startDate = DateTime(parsed.year, parsed.month, parsed.day);
  } else if (rawStartDate is String) {
    final parsed = DateTime.tryParse(rawStartDate);
    if (parsed != null) {
      startDate = DateTime(parsed.year, parsed.month, parsed.day);
    }
  }

  switch (repeatType) {
    case 'once':
      return today.isAtSameMomentAs(startDate);

    case 'daily':
      return true;

    case 'every_n_days':
      final int repeatEveryDays = data['repeatEveryDays'] is int
          ? data['repeatEveryDays']
          : int.tryParse(data['repeatEveryDays']?.toString() ?? '') ?? 0;

      if (repeatEveryDays <= 0) return false;

      final int difference = today.difference(startDate).inDays;
      return difference >= 0 && difference % repeatEveryDays == 0;

    case 'weekly_days':
    default:
      final List<String> diasSemana = List<String>.from(data['diasSemana'] ?? []);
      final String hoy = _getDiaSemanaActual();

      final normalizedDias = diasSemana.map((d) {
        return d
            .trim()
            .toLowerCase()
            .replaceAll('á', 'a')
            .replaceAll('é', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ó', 'o')
            .replaceAll('ú', 'u');
      }).toList();

      return normalizedDias.contains(hoy);
  }
}
  String? _completedByToday(Map<String, dynamic> data) {
    final fechaActual = _dbService.getFechaActualKey();
    final completedByDates = data['completedByDates'];

    if (completedByDates is Map<String, dynamic>) {
      return completedByDates[fechaActual]?.toString();
    }
    return null;
  }

  String _getCategory(Map<String, dynamic> data) {
    final rawCategory = data['category'] ?? data['categoria'] ?? data['tipo'] ?? data['type'] ?? '';
    final category = rawCategory.toString().trim();
    if (category.isEmpty) return 'Medicamentos';
    return category;
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medic')) return Icons.medication_rounded;
    if (lower.contains('alimen') || lower.contains('comida') || lower.contains('desayuno') || lower.contains('almuerzo') || lower.contains('cena')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('higiene') || lower.contains('aseo') || lower.contains('baño')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('salida') || lower.contains('visita')) {
      return Icons.groups_rounded;
    }
    return Icons.checklist_rounded;
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medic')) return const Color(0xFF7B1FA2);
    if (lower.contains('alimen') || lower.contains('comida') || lower.contains('desayuno') || lower.contains('almuerzo') || lower.contains('cena')) {
      return const Color(0xFF00C853);
    }
    if (lower.contains('higiene') || lower.contains('aseo') || lower.contains('baño')) {
      return const Color(0xFF2979FF);
    }
    if (lower.contains('salida') || lower.contains('visita')) {
      return const Color(0xFF00A86B);
    }
    return AppTheme.blue;
  }

  Map<String, List<QueryDocumentSnapshot>> _groupTasksByCategory(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = _getCategory(data);

      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(doc);
    }

    grouped.forEach((category, tasks) {
      tasks.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;

        final timeA = _timeToMinutes(dataA['time']);
        final timeB = _timeToMinutes(dataB['time']);
        return timeA.compareTo(timeB);
      });
    });
    return grouped;
  }

  void _showAddTaskDialog() {
    final TextEditingController titleCtrl = TextEditingController();

  String selectedCategory = 'Medicamentos';
  String selectedHour = '12';
  String selectedMinute = '00';
  String selectedPeriod = 'AM';
  String selectedMeal = 'Almuerzo';

  String repeatType = 'weekly_days';
  int repeatEveryDays = 2;
  final DateTime startDate = DateTime.now();

    final List<String> categories = ['Medicamentos', 'Alimentación', 'Higiene', 'Salidas / Visitas'];
    final List<String> mealOptions = ['Almuerzo', 'Colación', 'Once', 'Cena'];
    final List<Map<String, String>> weekDays = [
      {'label': 'Lunes', 'value': 'lunes'},
      {'label': 'Martes', 'value': 'martes'},
      {'label': 'Miércoles', 'value': 'miercoles'},
      {'label': 'Jueves', 'value': 'jueves'},
      {'label': 'Viernes', 'value': 'viernes'},
      {'label': 'Sábado', 'value': 'sabado'},
      {'label': 'Domingo', 'value': 'domingo'},
    ];
    

    final Set<String> selectedDays = {'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'};
    final List<String> hours = List.generate(12, (index) => '${index + 1}');
    final List<String> minutes = List.generate(60, (index) => index.toString().padLeft(2, '0'));
    final List<Map<String, String>> repeatOptions = [
  {'label': 'Una sola vez', 'value': 'once'},
  {'label': 'Todos los días', 'value': 'daily'},
  {'label': 'Días específicos', 'value': 'weekly_days'},
  {'label': 'Cada cierto número de días', 'value': 'every_n_days'},
];

final List<int> repeatEveryOptions = [2, 3, 4, 5, 7, 14, 30];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42, height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Agregar tarea', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text(widget.name, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          filled: true, fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(category), size: 20, color: _getCategoryColor(category)),
                                const SizedBox(width: 10),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() { selectedCategory = value; });
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        selectedCategory == 'Medicamentos' ? 'Toma de medicamentos' : selectedCategory == 'Alimentación' ? 'Tipo de alimentación' : selectedCategory == 'Salidas / Visitas' ? 'Nombre de la visita o lugar de salida' : 'Nombre de la tarea',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      if (selectedCategory == 'Alimentación')
                        DropdownButtonFormField<String>(
                          value: selectedMeal,
                          decoration: InputDecoration(
                            filled: true, fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: mealOptions.map((meal) => DropdownMenuItem(value: meal, child: Text(meal))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() { selectedMeal = value; });
                          },
                        )
                      else
                        TextField(
                          controller: titleCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: selectedCategory == 'Medicamentos' ? 'Ej: Metformina 500mg' : selectedCategory == 'Higiene' ? 'Ej: Baño' : 'Ej: Visita familiar o lugar de salida',
                            filled: true, fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      const SizedBox(height: 18),
                      const Text('Horario', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedHour,
                                decoration: const InputDecoration(labelText: 'Hora', border: InputBorder.none),
                                items: hours.map((hour) => DropdownMenuItem(value: hour, child: Text(hour))).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedHour = value; });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedMinute,
                                decoration: const InputDecoration(labelText: 'Min', border: InputBorder.none),
                                items: minutes.map((minute) => DropdownMenuItem(value: minute, child: Text(minute))).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedMinute = value; });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPeriod,
                                decoration: const InputDecoration(labelText: 'AM/PM', border: InputBorder.none),
                                items: const [DropdownMenuItem(value: 'AM', child: Text('AM')), DropdownMenuItem(value: 'PM', child: Text('PM'))],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedPeriod = value; });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Horario seleccionado: $selectedHour:$selectedMinute $selectedPeriod', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      const Text('Patrón de repetición', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
const SizedBox(height: 8),
DropdownButtonFormField<String>(
  value: repeatType,
  decoration: InputDecoration(
    filled: true,
    fillColor: Colors.grey.shade100,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  ),
  items: repeatOptions.map((option) {
    return DropdownMenuItem(
      value: option['value'],
      child: Text(option['label']!),
    );
  }).toList(),
  onChanged: (value) {
    if (value == null) return;
    setModalState(() {
      repeatType = value;
    });
  },
),

if (repeatType == 'every_n_days') ...[
  const SizedBox(height: 14),
  const Text('Repetir cada', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
  const SizedBox(height: 8),
  DropdownButtonFormField<int>(
    value: repeatEveryDays,
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    items: repeatEveryOptions.map((days) {
      return DropdownMenuItem(
        value: days,
        child: Text('Cada $days días'),
      );
    }).toList(),
    onChanged: (value) {
      if (value == null) return;
      setModalState(() {
        repeatEveryDays = value;
      });
    },
  ),
],

if (repeatType == 'weekly_days') ...[
  const SizedBox(height: 14),
  const Text('Días de repetición', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
  const SizedBox(height: 8),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: weekDays.map((day) {
      final label = day['label']!;
      final value = day['value']!;
      final isSelected = selectedDays.contains(value);

      return FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF00C853).withOpacity(0.18),
        checkmarkColor: const Color(0xFF00C853),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00A86B) : Colors.black54,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00C853) : Colors.grey.shade300,
        ),
        onSelected: (selected) {
          setModalState(() {
            if (selected) {
              selectedDays.add(value);
            } else {
              selectedDays.remove(value);
            }
          });
        },
      );
    }).toList(),
  ),
],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = selectedCategory == 'Alimentación' ? selectedMeal : titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(selectedCategory == 'Medicamentos' ? 'Completa el nombre del medicamento' : selectedCategory == 'Salidas / Visitas' ? 'Completa la visita o lugar de salida' : 'Completa el nombre de la tarea')));
                              return;
                            }
                          if (repeatType == 'weekly_days' && selectedDays.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Selecciona al menos un día de repetición'),
      backgroundColor: Colors.redAccent,
    ),
  );
  return;
}

                            final formattedTime = '$selectedHour:$selectedMinute $selectedPeriod';
                           final List<String> diasSemanaToSave = repeatType == 'weekly_days'
    ? selectedDays.toList()
    : [];

final String taskId = await _dbService.addTask(
  patientId: widget.patientId,
  title: title,
  time: formattedTime,
  category: selectedCategory,
  diasSemana: diasSemanaToSave,
  repeatType: repeatType,
  repeatEveryDays: repeatType == 'every_n_days' ? repeatEveryDays : null,
  startDate: startDate,
);

                            if (!Provider.of<SessionProvider>(context, listen: false).isAdmin) {
                              await NotificationService.scheduleMedicationReminder(
                                taskId: taskId, patientName: widget.name, medicationName: title, time: formattedTime, diasSemana: selectedDays.toList(), category: selectedCategory,
                              );
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarea agregada correctamente'), backgroundColor: Color(0xFF00C853)));
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Guardar tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // NUEVO: Modal para editar una tarea existente
  void _showEditTaskDialog(String taskId, Map<String, dynamic> currentData) {
    final String rawTime = currentData['time']?.toString() ?? '12:00 AM';
    final amPmRegex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = amPmRegex.firstMatch(rawTime);
    
    String initialHour = '12';
    String initialMinute = '00';
    String initialPeriod = 'AM';
    
    if (match != null) {
      initialHour = int.parse(match.group(1)!).toString();
      initialMinute = match.group(2)!;
      initialPeriod = match.group(3)!.toUpperCase();
    }

    String initialCategory = currentData['category']?.toString() ?? 'Medicamentos';
    if (!['Medicamentos', 'Alimentación', 'Higiene', 'Salidas / Visitas'].contains(initialCategory)) {
      initialCategory = 'Medicamentos';
    }

    String initialTitle = currentData['title']?.toString() ?? '';
    String initialMeal = 'Almuerzo';
    if (initialCategory == 'Alimentación' && ['Almuerzo', 'Colación', 'Once', 'Cena'].contains(initialTitle)) {
      initialMeal = initialTitle;
    }

    final TextEditingController titleCtrl = TextEditingController(text: initialCategory == 'Alimentación' ? '' : initialTitle);
    
    String selectedCategory = initialCategory;
    String selectedHour = initialHour;
    String selectedMinute = initialMinute;
    String selectedPeriod = initialPeriod;
    String selectedMeal = initialMeal;

    String repeatType = currentData['repeatType']?.toString() ?? 'weekly_days';
    int repeatEveryDays = currentData['repeatEveryDays'] is int
        ? currentData['repeatEveryDays']
        : int.tryParse(currentData['repeatEveryDays']?.toString() ?? '') ?? 2;

    DateTime startDate = DateTime.now();
    final rawStartDate = currentData['startDate'];
    if (rawStartDate is Timestamp) {
      startDate = rawStartDate.toDate();
    } else if (rawStartDate is String) {
      final parsed = DateTime.tryParse(rawStartDate);
      if (parsed != null) {
        startDate = parsed;
      }
    }
    
    List<String> rawDays = List<String>.from(currentData['diasSemana'] ?? []);
    final Set<String> selectedDays = rawDays.map((e) => e.toLowerCase()).toSet();

    final List<String> categories = ['Medicamentos', 'Alimentación', 'Higiene', 'Salidas / Visitas'];
    final List<String> mealOptions = ['Almuerzo', 'Colación', 'Once', 'Cena'];
    final List<Map<String, String>> weekDays = [
      {'label': 'Lunes', 'value': 'lunes'},
      {'label': 'Martes', 'value': 'martes'},
      {'label': 'Miércoles', 'value': 'miercoles'},
      {'label': 'Jueves', 'value': 'jueves'},
      {'label': 'Viernes', 'value': 'viernes'},
      {'label': 'Sábado', 'value': 'sabado'},
      {'label': 'Domingo', 'value': 'domingo'},
    ];

    final List<String> hours = List.generate(12, (index) => '${index + 1}');
    final List<String> minutes = List.generate(60, (index) => index.toString().padLeft(2, '0'));
    final List<Map<String, String>> repeatOptions = [
      {'label': 'Una sola vez', 'value': 'once'},
      {'label': 'Todos los días', 'value': 'daily'},
      {'label': 'Días específicos', 'value': 'weekly_days'},
      {'label': 'Cada cierto número de días', 'value': 'every_n_days'},
    ];
    final List<int> repeatEveryOptions = [2, 3, 4, 5, 7, 14, 30];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42, height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Editar tarea', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text(widget.name, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          filled: true, fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(category), size: 20, color: _getCategoryColor(category)),
                                const SizedBox(width: 10),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() { selectedCategory = value; });
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        selectedCategory == 'Medicamentos' ? 'Toma de medicamentos' : selectedCategory == 'Alimentación' ? 'Tipo de alimentación' : selectedCategory == 'Salidas / Visitas' ? 'Nombre de la visita o lugar de salida' : 'Nombre de la tarea',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      if (selectedCategory == 'Alimentación')
                        DropdownButtonFormField<String>(
                          value: selectedMeal,
                          decoration: InputDecoration(
                            filled: true, fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          items: mealOptions.map((meal) => DropdownMenuItem(value: meal, child: Text(meal))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() { selectedMeal = value; });
                          },
                        )
                      else
                        TextField(
                          controller: titleCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: selectedCategory == 'Medicamentos' ? 'Ej: Metformina 500mg' : selectedCategory == 'Higiene' ? 'Ej: Baño' : 'Ej: Visita familiar o lugar de salida',
                            filled: true, fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                      const SizedBox(height: 18),
                      const Text('Horario', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedHour,
                                decoration: const InputDecoration(labelText: 'Hora', border: InputBorder.none),
                                items: hours.map((hour) => DropdownMenuItem(value: hour, child: Text(hour))).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedHour = value; });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedMinute,
                                decoration: const InputDecoration(labelText: 'Min', border: InputBorder.none),
                                items: minutes.map((minute) => DropdownMenuItem(value: minute, child: Text(minute))).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedMinute = value; });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPeriod,
                                decoration: const InputDecoration(labelText: 'AM/PM', border: InputBorder.none),
                                items: const [DropdownMenuItem(value: 'AM', child: Text('AM')), DropdownMenuItem(value: 'PM', child: Text('PM'))],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setModalState(() { selectedPeriod = value; });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Horario seleccionado: $selectedHour:$selectedMinute $selectedPeriod', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 18),
                      const Text('Patrón de repetición', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: repeatType,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: repeatOptions.map((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            repeatType = value;
                          });
                        },
                      ),
                      if (repeatType == 'every_n_days') ...[
                        const SizedBox(height: 14),
                        const Text('Repetir cada', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: repeatEveryDays,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: repeatEveryOptions.map((days) {
                            return DropdownMenuItem(
                              value: days,
                              child: Text('Cada $days días'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() {
                              repeatEveryDays = value;
                            });
                          },
                        ),
                      ],
                      if (repeatType == 'weekly_days') ...[
                        const SizedBox(height: 14),
                        const Text('Días de repetición', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: weekDays.map((day) {
                            final label = day['label']!;
                            final value = day['value']!;
                            final isSelected = selectedDays.contains(value);

                            return FilterChip(
                              label: Text(label), selected: isSelected,
                              selectedColor: const Color(0xFF00C853).withOpacity(0.18),
                              checkmarkColor: const Color(0xFF00C853),
                              labelStyle: TextStyle(color: isSelected ? const Color(0xFF00A86B) : Colors.black54, fontWeight: FontWeight.w700),
                              side: BorderSide(color: isSelected ? const Color(0xFF00C853) : Colors.grey.shade300),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) { selectedDays.add(value); } else { selectedDays.remove(value); }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = selectedCategory == 'Alimentación' ? selectedMeal : titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(selectedCategory == 'Medicamentos' ? 'Completa el nombre del medicamento' : selectedCategory == 'Salidas / Visitas' ? 'Completa la visita o lugar de salida' : 'Completa el nombre de la tarea')));
                              return;
                            }
                            if (repeatType == 'weekly_days' && selectedDays.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Selecciona al menos un día de repetición'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            final formattedTime = '$selectedHour:$selectedMinute $selectedPeriod';
                            final List<String> diasSemanaToSave = repeatType == 'weekly_days'
                                ? selectedDays.toList()
                                : [];

                            try {
                              await _dbService.updateTaskData(widget.patientId, taskId, {
                                'title': title,
                                'time': formattedTime,
                                'category': selectedCategory,
                                'diasSemana': diasSemanaToSave,
                                'repeatType': repeatType,
                                'repeatEveryDays': repeatType == 'every_n_days' ? repeatEveryDays : null,
                                'startDate': startDate,
                              });

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarea actualizada'), backgroundColor: Color(0xFF00C853)));
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Actualizar tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditMedicalRecordDialog(Map<String, dynamic> currentData) {
    final bloodCtrl = TextEditingController(text: currentData['bloodType'] ?? '');
    final allergiesCtrl = TextEditingController(text: currentData['allergies'] ?? '');
    final pathCtrl = TextEditingController(text: currentData['pathologies'] ?? '');
    final contactNameCtrl = TextEditingController(text: currentData['emergencyContactName'] ?? '');
    final contactPhoneCtrl = TextEditingController(text: currentData['emergencyContactPhone'] ?? '');
    final obsCtrl = TextEditingController(text: currentData['observations'] ?? '');

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Editar Ficha Médica', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: bloodCtrl,
                      decoration: const InputDecoration(labelText: 'Tipo de Sangre', hintText: 'Ej: O+'),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: allergiesCtrl,
                      decoration: const InputDecoration(labelText: 'Alergias', hintText: 'Ej: Penicilina, Nueces'),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: pathCtrl,
                      decoration: const InputDecoration(labelText: 'Patologías / Diagnóstico', hintText: 'Ej: Hipertensión, Diabetes'),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const Align(alignment: Alignment.centerLeft, child: Text('Contacto de Emergencia', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactNameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre Contacto', hintText: 'Ej: Carlos López (Hijo)'),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: contactPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono Contacto', hintText: 'Ej: +56 9 1234 5678'),
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Observaciones Generales'),
                    ),
                  ],
                ),
              ),
              actions: isSaving
                  ? [const CircularProgressIndicator(color: AppTheme.blue)]
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setStateDialog(() => isSaving = true);
                          try {
                            await _dbService.updateMedicalRecord(widget.patientId, {
                              'bloodType': bloodCtrl.text.trim(),
                              'allergies': allergiesCtrl.text.trim(),
                              'pathologies': pathCtrl.text.trim(),
                              'emergencyContactName': contactNameCtrl.text.trim(),
                              'emergencyContactPhone': contactPhoneCtrl.text.trim(),
                              'observations': obsCtrl.text.trim(),
                            });
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficha actualizada'), backgroundColor: Colors.green));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            setStateDialog(() => isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
                        child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final bool isAdmin = session.isAdmin;
    final int tabCount = isAdmin ? 3 : 2;

    if (session.uid.isEmpty || session.centroId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.blue),
        ),
      );
    }

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: AppTheme.blue, 
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).snapshots(),
            builder: (context, snapshot) {
              String name = widget.name;
              String details = widget.details;
              String photoUrl = '';
              String initials = widget.initials;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? widget.name;
                details = data['details'] ?? widget.details;
                photoUrl = data['photoUrl'] ?? '';
                initials = data['initials'] ?? widget.initials;
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: photoUrl.isNotEmpty
                        ? (photoUrl.startsWith('data:image') || !photoUrl.startsWith('http')
                            ? MemoryImage(base64Decode(photoUrl.split(',').last))
                            : NetworkImage(photoUrl) as ImageProvider)
                        : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            initials.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          details,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.history_edu, color: Colors.white),
                tooltip: 'Auditoría Semanal',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientHistoryScreen(
                        patientId: widget.patientId,
                        patientName: widget.name,
                      ),
                    ),
                  );
                },
              ),
          ],
          bottom: TabBar(
            indicatorColor: const Color(0xFF00C853), indicatorWeight: 3,
            labelColor: Colors.white, unselectedLabelColor: Colors.white70,
            tabs: [
              const Tab(text: 'Tareas'),
              if (isAdmin) const Tab(text: 'Asignación'),
              const Tab(text: 'Ficha Médica'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTasksTab(context, session),
            if (isAdmin) _buildAssignmentsTab(context),
            _buildMedicalRecordTab(context, session),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordTab(BuildContext context, SessionProvider session) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Error al cargar la ficha médica.'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? 'Estable';
        final bloodType = data['bloodType']?.toString().isNotEmpty == true ? data['bloodType'] : 'No registrado';
        final allergies = data['allergies']?.toString().isNotEmpty == true ? data['allergies'] : 'No registradas';
        final pathologies = data['pathologies']?.toString().isNotEmpty == true ? data['pathologies'] : 'No registradas';
        final emergencyName = data['emergencyContactName']?.toString().isNotEmpty == true ? data['emergencyContactName'] : 'Sin contacto';
        final emergencyPhone = data['emergencyContactPhone']?.toString().isNotEmpty == true ? data['emergencyContactPhone'] : '--';
        final observations = data['observations']?.toString().isNotEmpty == true ? data['observations'] : 'Sin observaciones generales.';
        
        final List<dynamic> rawFiles = data['medicalRecordFiles'] as List<dynamic>? ?? [];
        final List<Map<String, String>> medicalFiles = rawFiles.map((item) {
          final m = item as Map<dynamic, dynamic>;
          return {
            'file': m['file']?.toString() ?? '',
            'name': m['name']?.toString() ?? '',
          };
        }).toList();

        final legacyFile = data['medicalRecordFile']?.toString() ?? '';
        final legacyFileName = data['medicalRecordFileName']?.toString() ?? '';
        if (medicalFiles.isEmpty && legacyFile.isNotEmpty) {
          medicalFiles.add({
            'file': legacyFile,
            'name': legacyFileName,
          });
        }

        return ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildMedicalInfoCard(
              title: 'Estado de Salud',
              icon: Icons.health_and_safety_rounded,
              color: AppTheme.blue,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailStatusBadge(status),
                    if (session.isAdmin)
                      TextButton.icon(
                        onPressed: () => _showChangeStatusDialog(context, status),
                        icon: const Icon(Icons.edit, color: AppTheme.blue, size: 16),
                        label: const Text('Cambiar Estado', style: TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            if (session.isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showEditMedicalRecordDialog(data),
                  icon: const Icon(Icons.edit, color: AppTheme.blue, size: 18),
                  label: const Text('Editar Ficha', style: TextStyle(color: AppTheme.blue, fontWeight: FontWeight.bold)),
                ),
              ),
            
            _buildMedicalInfoCard(
              title: 'Información Clínicas',
              icon: Icons.favorite,
              color: Colors.redAccent,
              children: [
                _buildInfoRow('Tipo de Sangre', bloodType),
                const Divider(height: 24),
                _buildInfoRow('Alergias', allergies),
                const Divider(height: 24),
                _buildInfoRow('Patologías Crónicas', pathologies),
              ],
            ),
            const SizedBox(height: 15),

            _buildMedicalInfoCard(
              title: 'Contacto de Emergencia',
              icon: Icons.contact_phone,
              color: Colors.orange,
              children: [
                _buildInfoRow('Nombre', emergencyName),
                const Divider(height: 24),
                _buildInfoRow('Teléfono', emergencyPhone),
              ],
            ),
            const SizedBox(height: 15),

            _buildMedicalInfoCard(
              title: 'Observaciones Generales',
              icon: Icons.note_alt,
              color: AppTheme.blue,
              children: [
                Text(observations, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
              ],
            ),
            const SizedBox(height: 15),

            _buildMedicalInfoCard(
              title: 'Fichas Físicas Adjuntas',
              icon: Icons.attach_file_rounded,
              color: Colors.teal,
              children: [
                if (medicalFiles.isEmpty) ...[
                  const Text(
                    'No hay ningún documento o foto de la ficha médica adjunto.',
                    style: TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                  if (session.isAdmin) ...[
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => _attachMedicalRecordFile(context, widget.patientId),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Adjuntar Documento o Foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: medicalFiles.length,
                    separatorBuilder: (context, index) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final fileMap = medicalFiles[index];
                      final fName = fileMap['name'] ?? '';
                      final fData = fileMap['file'] ?? '';
                      final isPdf = fName.toLowerCase().endsWith('.pdf');

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                color: Colors.teal,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fName.isNotEmpty ? fName : 'Ficha Adjunta',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPdf ? 'Documento PDF' : 'Imagen / Foto',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (session.isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Eliminar Documento', style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: Text('¿Estás seguro de que deseas eliminar "$fName"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      if (fData == legacyFile && fName == legacyFileName) {
                                        await FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).update({
                                          'medicalRecordFile': FieldValue.delete(),
                                          'medicalRecordFileName': FieldValue.delete(),
                                        });
                                      } else {
                                        await FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).update({
                                          'medicalRecordFiles': FieldValue.arrayRemove([fileMap]),
                                        });
                                      }
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Documento eliminado'), backgroundColor: Colors.green),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (isPdf) {
                                      _openPdfFile(context, fData, fName);
                                    } else {
                                      _viewAttachedImage(context, fData);
                                    }
                                  },
                                  icon: const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                                  label: Text(
                                    isPdf ? 'Ver PDF' : 'Ver Imagen',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  if (session.isAdmin) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _attachMedicalRecordFile(context, widget.patientId),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Adjuntar Otro Documento o Foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMedicalInfoCard({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildTasksTab(BuildContext context, SessionProvider session) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getCuidadoresStream(session.centroId),
      builder: (context, snapshotCaregivers) {
        
        final Map<String, String> caregiverMap = {
          session.uid: '${session.nombre} (Yo)',
        };

        if (snapshotCaregivers.hasData) {
          for (final doc in snapshotCaregivers.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            caregiverMap[doc.id] = data['nombre'] ?? 'Cuidador';
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pacientes')
              .doc(widget.patientId)
              .collection('tareas')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar las tareas', style: TextStyle(color: Colors.redAccent)));
            }

            final docs = snapshot.data?.docs ?? [];

final docsToday = docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  return _isTaskScheduledForToday(data);
}).toList();

if (docsToday.isEmpty) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
    children: [
      const Text('Tareas por categoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
      const SizedBox(height: 6),
      const Text('Registro diario de cuidados realizados al paciente.', style: TextStyle(fontSize: 14, color: Colors.black54)),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.checklist_rounded, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No hay tareas para hoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
          ],
        ),
      ),
      if (session.isAdmin) ...[
        const SizedBox(height: 18),
        _buildAddTaskButton(),
      ],
    ],
  );
}

final groupedTasks = _groupTasksByCategory(docsToday);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                const Text('Tareas por categoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 6),
                const Text('Registro diario de cuidados realizados al paciente.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 18),
                ...groupedTasks.entries.map((entry) {
                  final category = entry.key;
                 final tasksToday = entry.value;

        

                  final completed = tasksToday.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _isCompletedToday(data);
                  }).length;

                  return _buildCategoryCard(
                    category: category, completed: completed, total: tasksToday.length, tasks: tasksToday, caregiverMap: caregiverMap, session: session,
                  );
                }).toList(),
                if (session.isAdmin) ...[const SizedBox(height: 8), _buildAddTaskButton()],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddTaskButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Añadir tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String category,
    required int completed,
    required int total,
    required List<QueryDocumentSnapshot> tasks,
    required Map<String, String> caregiverMap,
    required SessionProvider session,
  }) {
    final color = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.15), child: Icon(_getCategoryIcon(category), color: color, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(category, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87))),
                Text('$completed/$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
              ],
            ),
          ),
          ...tasks.map((taskDoc) {
            final data = taskDoc.data() as Map<String, dynamic>;
            final isCompletedToday = _isCompletedToday(data);
            final completedByUid = _completedByToday(data);
            final caregiverName = completedByUid != null ? caregiverMap[completedByUid] : null;

            return _buildTaskRow(
              taskId: taskDoc.id, 
              title: data['title'] ?? '', 
              time: _formatTime(data['time']), 
              isChecked: isCompletedToday, 
              isAdmin: session.isAdmin, 
              caregiverName: caregiverName, 
              completedByUid: completedByUid,
              color: color,
              rawData: data,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTaskRow({
    required String taskId,
    required String title,
    required String time,
    required bool isChecked,
    required bool isAdmin,
    required String? caregiverName,
    required String? completedByUid,
    required Color color,
    required Map<String, dynamic> rawData,
  }) {
    final row = InkWell(
      onTap: isAdmin ? null : () {
        final currentUid = Provider.of<SessionProvider>(context, listen: false).uid;
        if (isChecked && completedByUid != null && completedByUid != currentUid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solo puedes desmarcar tareas que tú mismo completaste.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
        _dbService.updateTaskStatus(widget.patientId, taskId, !isChecked, currentUid);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isChecked ? const Color(0xFF00C853) : Colors.white, border: Border.all(color: isChecked ? const Color(0xFF00C853) : Colors.grey.shade300, width: 2)),
              child: isChecked ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isEmpty ? 'Tarea sin nombre' : title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87, decoration: isChecked ? TextDecoration.lineThrough : null, decorationThickness: 2)),
                  if (isChecked && caregiverName != null) ...[
                    const SizedBox(height: 4),
                    Text('Completado por: $caregiverName', style: const TextStyle(fontSize: 12, color: AppTheme.blue, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isAdmin) 
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppTheme.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditTaskDialog(taskId, rawData),
              ),
            const SizedBox(width: 5),
            Text(time, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );

    if (!isAdmin) return row;

    return Dismissible(
      key: Key(taskId),
      direction: DismissDirection.endToStart,
      background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Eliminar tarea', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('¿Deseas eliminar la tarea "$title"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
            ],
          ),
        );
      },
      onDismissed: (_) { _dbService.deleteTask(widget.patientId, taskId); },
      child: row,
    );
  }

  Widget _buildAssignmentsTab(BuildContext context) {
    final session = context.read<SessionProvider>();
    final List<String> dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getCuidadoresStream(session.centroId),
      builder: (context, caregiversSnapshot) {
        if (caregiversSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
        }

        if (caregiversSnapshot.hasError) {
          return const Center(child: Text('Error al obtener la lista de cuidadores.'));
        }

        Map<String, String> caregiverNames = {
          session.uid: '${session.nombre} (Yo)',
        };
        
        List<QueryDocumentSnapshot> caregiversDocs = [];

        if (caregiversSnapshot.hasData) {
          caregiversDocs = caregiversSnapshot.data!.docs;
          for (final doc in caregiversDocs) {
            caregiverNames[doc.id] = (doc.data() as Map<String, dynamic>)['nombre'] ?? 'Sin nombre';
          }
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).snapshots(),
          builder: (context, patientSnapshot) {
            if (patientSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.blue));
            }

            if (!patientSnapshot.hasData || !patientSnapshot.data!.exists) {
              return const Center(child: Text('No se pudo cargar la información del paciente.'));
            }

            final patientData = patientSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final List<String> asignaciones = List<String>.from(patientData['asignaciones'] ?? []);

            return ListView.separated(
              padding: const EdgeInsets.all(20.0),
              itemCount: dias.length,
              separatorBuilder: (context, index) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                final String dia = dias[index];
                final String normalizedDia = _normalizeDia(dia);
                final String prefix = '${normalizedDia}_';

                final List<String> assignedUids = asignaciones
                    .where((asig) => asig.startsWith(prefix))
                    .map((asig) => asig.substring(prefix.length))
                    .toList();

                return Container(
                  decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dia, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.blue, size: 24),
                            onPressed: () {
                              _showAssignCaregiverDialog(
                                context: context, dia: dia, alreadyAssignedUids: assignedUids, allCaregivers: caregiversDocs,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      assignedUids.isEmpty
                          ? const Text('Sin cuidadores asignados', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: assignedUids.map((uid) {
                                final String nombreCuidador = caregiverNames[uid] ?? 'Cargando...';

                                return Chip(
                                  backgroundColor: AppTheme.blue.withOpacity(0.08), side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  label: Text(nombreCuidador, style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                                  deleteIcon: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
                                  onDeleted: () async {
                                    try {
                                      await _dbService.desasignarCuidadorDePaciente(
                                        pacienteId: widget.patientId, cuidadorId: uid, diaSemana: normalizedDia,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se quitó a $nombreCuidador de la asignación del $dia')));
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String lowerStatus = status.toLowerCase();

    if (lowerStatus == 'estable') {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else if (lowerStatus == 'atención' || lowerStatus == 'atencion') {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFEF6C00);
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
      ),
    );
  }

  void _showChangeStatusDialog(BuildContext context, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cambiar Estado de Salud', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Estable', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: currentStatus.toLowerCase() == 'estable' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () async {
                  await FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).update({
                    'status': 'Estable',
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: const Text('Atención Requerida', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: (currentStatus.toLowerCase() == 'atención' || currentStatus.toLowerCase() == 'atencion')
                    ? const Icon(Icons.check, color: Colors.orange)
                    : null,
                onTap: () async {
                  await FirebaseFirestore.instance.collection('pacientes').doc(widget.patientId).update({
                    'status': 'Atención',
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _attachMedicalRecordFile(BuildContext context, String patientId) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto (Cámara)'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de Galería'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Seleccionar Archivo PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (option == null) return;

    try {
      if (option == 'pdf') {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          final bytes = file.bytes;
          if (bytes != null) {
            if (bytes.length > 900 * 1024) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El archivo es demasiado grande (Límite: 900KB para Firestore)'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final base64String = 'data:application/pdf;base64,${base64Encode(bytes)}';
            await FirebaseFirestore.instance.collection('pacientes').doc(patientId).update({
              'medicalRecordFiles': FieldValue.arrayUnion([
                {
                  'file': base64String,
                  'name': file.name,
                }
              ]),
            });
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF adjuntado exitosamente'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        final picker = ImagePicker();
        final pickedImage = await picker.pickImage(
          source: option == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 1000,
        );

        if (pickedImage != null) {
          final croppedPath = await ImageHelper.cropImage(
            sourcePath: pickedImage.path,
            isSquare: false,
          );

          if (croppedPath != null) {
            final bytes = await XFile(croppedPath).readAsBytes();
            if (bytes.length > 900 * 1024) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La imagen es demasiado grande. Intenta recortarla más o bajar la calidad.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            final fileName = pickedImage.name;
            await FirebaseFirestore.instance.collection('pacientes').doc(patientId).update({
              'medicalRecordFiles': FieldValue.arrayUnion([
                {
                  'file': base64String,
                  'name': fileName,
                }
              ]),
            });
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Imagen adjuntada exitosamente'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al adjuntar archivo: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _openPdfFile(BuildContext context, String base64Data, String fileName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
      );

      final cleanBase64 = base64Data.split(',').last;
      final bytes = base64Decode(cleanBase64);
      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final file = File('${tempDir.path}/$safeName');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      Navigator.pop(context);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el PDF: ${result.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _viewAttachedImage(BuildContext context, String base64Data) {
    final cleanBase64 = base64Data.split(',').last;
    final imageBytes = base64Decode(cleanBase64);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}