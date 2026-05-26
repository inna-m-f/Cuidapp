import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Santiago'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleMedicationReminder({
    required String taskId,
    required String patientName,
    required String medicationName,
    required String time,
    required List<String> diasSemana,
  }) async {
    if (kIsWeb) return;

    final parsedTime = _parseHourMinutePeriod(time);
    if (parsedTime == null) return;

    final int medicationHour = parsedTime['hour']!;
    final int medicationMinute = parsedTime['minute']!;

    for (final dia in diasSemana) {
      tz.TZDateTime medicationDate = _nextInstanceOfDayAndTime(
        diaSemana: dia,
        hour: medicationHour,
        minute: medicationMinute,
      );

      tz.TZDateTime alertDate =
          medicationDate.subtract(const Duration(minutes: 5));

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      if (alertDate.isBefore(now)) {
        // 1. Programar alerta de prueba inmediata (disparo único) para desarrollo si el medicamento es pronto
        if (medicationDate.isAfter(now)) {
          final int testId = (taskId.hashCode.abs() + dia.hashCode.abs() + 1000000) % 2147483647;
          debugPrint('[NotificationService] Programando alerta de prueba inmediata ID $testId para sonar en 5 segundos.');
          await _notifications.zonedSchedule(
            id: testId,
            title: 'Alerta de medicamento (Prueba)',
            body:
                'Quedan 5 minutos para administrar $medicationName a $patientName.',
            scheduledDate: now.add(const Duration(seconds: 5)),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'medication_reminders',
                'Alertas de medicamentos',
                channelDescription:
                    'Recordatorios automáticos 5 minutos antes de la toma de medicamentos.',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }

        // 2. Desplazar la alerta semanal 7 días al futuro para que no dé error de fecha pasada
        medicationDate = medicationDate.add(const Duration(days: 7));
        alertDate = medicationDate.subtract(const Duration(minutes: 5));
      }

      final int notificationId = _notificationId(taskId, dia);

      debugPrint('[NotificationService] Programando Alerta Semanal ID $notificationId ($medicationName para $patientName) el día $dia a las $alertDate (Medicamento a las $medicationDate)');

      await _notifications.zonedSchedule(
        id: notificationId,
        title: 'Alerta de medicamento',
        body:
            'Quedan 5 minutos para administrar $medicationName a $patientName.',
        scheduledDate: alertDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Alertas de medicamentos',
            channelDescription:
                'Recordatorios automáticos 5 minutos antes de la toma de medicamentos.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> cancelMedicationReminder({
    required String taskId,
    required List<String> diasSemana,
  }) async {
    if (kIsWeb) return;

    for (final dia in diasSemana) {
      await _notifications.cancel(
        id: _notificationId(taskId, dia),
      );
    }
  }

  static Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  static Map<String, int>? _parseHourMinutePeriod(String value) {
    final String raw = value.trim().toUpperCase();

    final RegExp regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final RegExpMatch? match = regex.firstMatch(raw);

    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String period = match.group(3)!;

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return {
      'hour': hour,
      'minute': minute,
    };
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime({
    required String diaSemana,
    required int hour,
    required int minute,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final int targetWeekday = _weekdayNumber(diaSemana);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != targetWeekday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static int _weekdayNumber(String diaSemana) {
    switch (diaSemana.toLowerCase()) {
      case 'lunes':
        return DateTime.monday;
      case 'martes':
        return DateTime.tuesday;
      case 'miercoles':
      case 'miércoles':
        return DateTime.wednesday;
      case 'jueves':
        return DateTime.thursday;
      case 'viernes':
        return DateTime.friday;
      case 'sabado':
      case 'sábado':
        return DateTime.saturday;
      case 'domingo':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  static int _notificationId(String taskId, String diaSemana) {
    return '$taskId-$diaSemana'.hashCode.abs() % 2147483647;
  }

  static Future<void> syncCaregiverReminders({
    required String uidCuidador,
    required List<QueryDocumentSnapshot> patientDocs,
  }) async {
    if (kIsWeb) return;

    try {
      // 1. Cancelar todas las alarmas previas en este dispositivo para empezar limpio
      await _notifications.cancelAll();

      // 2. Iterar sobre cada paciente asignado
      for (final doc in patientDocs) {
        final String patientId = doc.id;
        final String patientName = (doc.data() as Map<String, dynamic>)['name'] ??
            (doc.data() as Map<String, dynamic>)['nombre'] ??
            '';
        final List<String> asignaciones = List<String>.from(
          (doc.data() as Map<String, dynamic>)['asignaciones'] ?? [],
        );

        // Encontrar los días en que este cuidador específico está asignado al paciente
        final List<String> assignedDays = [];
        for (final asignacion in asignaciones) {
          final parts = asignacion.split('_');
          if (parts.length == 2 && parts[1] == uidCuidador) {
            assignedDays.add(parts[0].toLowerCase());
          }
        }

        if (assignedDays.isEmpty) continue;

        // Obtener tareas de tipo Medicamentos para este paciente
        final QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(patientId)
            .collection('tareas')
            .where('category', isEqualTo: 'Medicamentos')
            .get();

        for (final taskDoc in tasksSnapshot.docs) {
          final Map<String, dynamic> taskData =
              taskDoc.data() as Map<String, dynamic>;
          
          final String taskId = taskDoc.id;
          final String medicationName = taskData['title'] ?? '';
          final String time = taskData['time'] ?? '';
          final List<String> taskDays = List<String>.from(
            taskData['diasSemana'] ?? [],
          );

          // Filtrar días en común (días de la tarea en que el cuidador está asignado)
          final List<String> daysToSchedule = taskDays
              .where((day) => assignedDays.contains(day.toLowerCase()))
              .toList();

          if (daysToSchedule.isNotEmpty) {
            await scheduleMedicationReminder(
              taskId: taskId,
              patientName: patientName,
              medicationName: medicationName,
              time: time,
              diasSemana: daysToSchedule,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error al sincronizar alarmas: $e');
    }
  }
}
