import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PatientDetailScreen extends StatefulWidget {
  final String initials;
  final String name;
  final String details;

  const PatientDetailScreen({
    Key? key,
    required this.initials,
    required this.name,
    required this.details,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  // Estado simulado para las tareas de la maqueta
  bool _aseoMatinal = true; // Simula una tarea ya completada
  bool _medicamentos = false;
  bool _bano = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white, fontSize: 18),
            ),
            Text(
              widget.details,
              style: const TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: AppTheme.blue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tareas programadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            
            // Lista de Tareas
            Expanded(
              child: ListView(
                children: [
                  _buildTaskTile('Aseo matinal', '07:00', _aseoMatinal, (val) {
                    setState(() => _aseoMatinal = val ?? false);
                  }),
                  const SizedBox(height: 12),
                  _buildTaskTile('Medicamentos (Metformina 500mg)', '08:00', _medicamentos, (val) {
                    setState(() => _medicamentos = val ?? false);
                  }),
                  const SizedBox(height: 12),
                  _buildTaskTile('Baño', '14:00', _bano, (val) {
                    setState(() => _bano = val ?? false);
                  }),
                ],
              ),
            ),
            
            // Botón Añadir Tarea
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Lógica para agregar tarea
                },
                child: const Text(
                  '+ Añadir tarea',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Componente reutilizable para cada tarea de la lista
  Widget _buildTaskTile(String title, String time, bool isChecked, ValueChanged<bool?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: onChanged,
        activeColor: AppTheme.green,
        checkColor: AppTheme.white,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
        subtitle: Text(
          time,
          style: TextStyle(
            color: isChecked ? Colors.grey.shade400 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}