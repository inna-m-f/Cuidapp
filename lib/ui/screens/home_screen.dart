import 'package:flutter/material.dart';
import '../../core/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, 
      appBar: AppBar(
        title: const Text(
          'Pacientes del Centro',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.white),
        ),

        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          // Barra de búsqueda flotante
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar paciente...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.blue),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: AppTheme.blue, width: 2),
                ),
              ),
            ),
          ),
          
          // Lista de pacientes (ListView)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              children: [
                _buildPatientCard(
                  initials: 'MG',
                  name: 'María González',
                  details: '78 años • Habitación 102',
                  status: 'Estable',
                  progressChips: ['4/5', '3/3', '2/2'],
                ),
                const SizedBox(height: 15),
                _buildPatientCard(
                  initials: 'JM',
                  name: 'José Martínez Ruiz',
                  details: '82 años',
                  status: 'Atención',
                  progressChips: ['0/1'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({
    required String initials,
    required String name,
    required String details,
    required String status,
    required List<String> progressChips,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar con iniciales
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.blue.withOpacity(0.1),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppTheme.blue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 15),
          
          // Información del paciente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: progressChips.map((chipText) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        chipText,
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}