import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/database_service.dart';
import 'patient_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({Key? key}) : super(key: key);

  final DatabaseService _dbService = DatabaseService();

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

          // Lista de pacientes desde Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getPacientesStream(),
              builder: (context, snapshot) {
                // Estado 1: Cargando datos
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.blue),
                  );
                }

                
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error al cargar la información',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay pacientes registrados.',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  );
                }

                
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 15),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    // Evita nulos si un campo falta en Firebase
                    String initials = data['initials'] ?? '';
                    String name = data['name'] ?? 'Sin nombre';
                    String details = data['details'] ?? '';
                    String status = data['status'] ?? 'Sin estado';
                    List<String> progressChips = List<String>.from(data['progressChips'] ?? []);

                    return _buildPatientCard(
                      context,
                      initials: initials,
                      name: name,
                      details: details,
                      status: status,
                      progressChips: progressChips,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildPatientCard(
    BuildContext context, {
    required String initials,
    required String name,
    required String details,
    required String status,
    required List<String> progressChips,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailScreen(
              initials: initials,
              name: name,
              details: details,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      ),
    );
  }
}