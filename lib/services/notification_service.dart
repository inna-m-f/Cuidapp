import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Timer? _syncDebouncer;
  static Set<String> _previouslyScheduledTaskIds = {};

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

    await _notifications.initialize(settings: settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    // Explicitly register notification channels to ensure the OS handles them correctly.
    const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
      'task_reminders',
      'Recordatorios de tareas',
      description: 'Recordatorios automáticos y alertas de retraso de tareas.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel invitationsChannel =
        AndroidNotificationChannel(
          'invitations_channel',
          'Invitaciones a Centros',
          description: 'Notificaciones sobre invitaciones a nuevos centros.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

    await androidPlugin?.createNotificationChannel(taskChannel);
    await androidPlugin?.createNotificationChannel(invitationsChannel);
  }

  static void syncCaregiverRemindersDebounced({
    required String uidCuidador,
    required List<QueryDocumentSnapshot> patientDocs,
  }) {
    _syncDebouncer?.cancel();
    _syncDebouncer = Timer(const Duration(milliseconds: 500), () {
      syncCaregiverReminders(
        uidCuidador: uidCuidador,
        patientDocs: patientDocs,
      );
    });
  }

  static Future<void> scheduleMedicationReminder({
    required String taskId,
    required String patientName,
    required String medicationName,
    required String time,
    List<String>? diasSemana,
    bool isCompletedToday = false,
    String category = 'Medicamentos',
    DateTime? specificDate,
  }) async {
    if (kIsWeb) return;

    final parsedTime = _parseHourMinutePeriod(time);
    if (parsedTime == null) return;

    final int medicationHour = parsedTime['hour']!;
    final int medicationMinute = parsedTime['minute']!;

    final String cleanCategory = category.trim().toLowerCase();
    String titleText = 'Alerta de tarea';
    String bodyText =
        'Quedan 5 minutos para la tarea "$medicationName" de $patientName.';
    String overdueTitle = 'Tarea atrasada';
    String overdueBody =
        'La tarea "$medicationName" para $patientName está atrasada (debía realizarse a las $time).';

    if (cleanCategory == 'medicamentos') {
      titleText = 'Alerta de medicamento';
      bodyText =
          'Quedan 5 minutos para administrar $medicationName a $patientName.';
      overdueTitle = 'Medicamento atrasado';
      overdueBody =
          'El medicamento $medicationName para $patientName está atrasado (debía administrarse a las $time).';
    } else if (cleanCategory == 'alimentación' ||
        cleanCategory == 'alimentacion') {
      titleText = 'Alerta de alimentación';
      bodyText =
          'Quedan 5 minutos para la comida de $patientName: $medicationName.';
      overdueTitle = 'Comida atrasada';
      overdueBody =
          'La comida "$medicationName" para $patientName está atrasada (debía servirse a las $time).';
    } else if (cleanCategory == 'higiene') {
      titleText = 'Alerta de higiene';
      bodyText =
          'Quedan 5 minutos para la higiene de $patientName: $medicationName.';
      overdueTitle = 'Higiene atrasada';
      overdueBody =
          'La tarea de higiene "$medicationName" para $patientName está atrasada (debía realizarse a las $time).';
    } else if (cleanCategory == 'salidas / visitas' ||
        cleanCategory == 'salidas' ||
        cleanCategory == 'visitas') {
      titleText = 'Alerta de visitas/salidas';
      bodyText =
          'Quedan 5 minutos para la visita/salida de $patientName: $medicationName.';
      overdueTitle = 'Visita/Salida atrasada';
      overdueBody =
          'La visita/salida "$medicationName" para $patientName está atrasada (debía realizarse a las $time).';
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (specificDate != null) {
      final tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        specificDate.year,
        specificDate.month,
        specificDate.day,
        medicationHour,
        medicationMinute,
      );

      tz.TZDateTime alertDate = scheduledDate.subtract(
        const Duration(minutes: 5),
      );

      // CORRECCIÓN 1: Evitar el salto automático a la próxima semana si la tarea es en < 5 min
      if (scheduledDate.isBefore(now)) {
        final DateTime nowDt = DateTime.now();
        if (specificDate.year == nowDt.year &&
            specificDate.month == nowDt.month &&
            specificDate.day == nowDt.day &&
            !isCompletedToday) {
          final difference = nowDt.difference(scheduledDate).inMinutes;
          if (difference >= 0) {
            final SharedPreferences prefs =
                await SharedPreferences.getInstance();
            final String todayKey =
                '${nowDt.year}-${nowDt.month.toString().padLeft(2, '0')}-${nowDt.day.toString().padLeft(2, '0')}';
            final String prefKey = 'notified_${taskId}_${todayKey}_overdue';
            if (prefs.getBool(prefKey) != true) {
              final int overdueId =
                  (taskId.hashCode.abs() + specificDate.day + 5000000) %
                  2147483647;
              debugPrint(
                '[NotificationService] Programando alerta de retraso ID $overdueId.',
              );
              await _notifications.zonedSchedule(
                id: overdueId,
                title: overdueTitle,
                body: overdueBody,
                scheduledDate: now.add(const Duration(seconds: 1)),
                notificationDetails: const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'task_reminders',
                    'Recordatorios de tareas',
                    channelDescription: 'Recordatorios de tareas atrasadas.',
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
              await prefs.setBool(prefKey, true);
            } else {
              debugPrint(
                '[NotificationService] Alerta de retraso ya notificada hoy para tarea $taskId. Ignorando.',
              );
            }
          }
        }
        return; // Retornamos porque la tarea ya está en el pasado
      } else if (alertDate.isBefore(now)) {
        // La tarea ocurrirá en menos de 5 minutos, la hacemos sonar en 5 segundos
        alertDate = now.add(const Duration(seconds: 5));
      }

      final int notificationId =
          (taskId.hashCode.abs() + specificDate.day) % 2147483647;
      debugPrint(
        '[NotificationService] Programando Alerta Única ID $notificationId el día $specificDate a las $alertDate',
      );
      await _notifications.zonedSchedule(
        id: notificationId,
        title: titleText,
        body: bodyText,
        scheduledDate: alertDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Recordatorios de tareas',
            channelDescription: 'Recordatorios automáticos 5 minutos antes.',
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

      final int overdueId =
          (taskId.hashCode.abs() + specificDate.day + 5000000) % 2147483647;
      debugPrint(
        '[NotificationService] Programando Alerta de Retraso Única ID $overdueId el día $specificDate a las $scheduledDate',
      );
      await _notifications.zonedSchedule(
        id: overdueId,
        title: overdueTitle,
        body: overdueBody,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Recordatorios de tareas',
            channelDescription: 'Recordatorios de tareas atrasadas.',
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
    } else if (diasSemana != null) {
      for (final dia in diasSemana) {
        final DateTime nowDt = DateTime.now();
        final int todayWeekday = nowDt.weekday;
        final int targetWeekday = _weekdayNumber(dia);

        if (todayWeekday == targetWeekday && !isCompletedToday) {
          final DateTime taskTimeToday = DateTime(
            nowDt.year,
            nowDt.month,
            nowDt.day,
            medicationHour,
            medicationMinute,
          );

          if (nowDt.isAfter(taskTimeToday)) {
            final difference = nowDt.difference(taskTimeToday).inMinutes;
            if (difference >= 0) {
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              final String todayKey =
                  '${nowDt.year}-${nowDt.month.toString().padLeft(2, '0')}-${nowDt.day.toString().padLeft(2, '0')}';
              final String prefKey =
                  'notified_${taskId}_${todayKey}_overdue_immediate';

              if (prefs.getBool(prefKey) != true) {
                // CORRECCIÓN 2: Uso del ID con + 6000000 para no aplastar la alarma semanal programada abajo
                final int immediateOverdueId =
                    (taskId.hashCode.abs() + dia.hashCode.abs() + 6000000) %
                    2147483647;
                debugPrint(
                  '[NotificationService] Programando alerta de retraso ID $immediateOverdueId.',
                );
                await _notifications.zonedSchedule(
                  id: immediateOverdueId,
                  title: overdueTitle,
                  body: overdueBody,
                  scheduledDate: now.add(const Duration(seconds: 1)),
                  notificationDetails: const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'task_reminders',
                      'Recordatorios de tareas',
                      channelDescription: 'Recordatorios de tareas atrasadas.',
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
                await prefs.setBool(prefKey, true);
              } else {
                debugPrint(
                  '[NotificationService] Alerta de retraso ya notificada hoy para tarea $taskId. Ignorando.',
                );
              }
            }
          }
        }

        tz.TZDateTime medicationDate = _nextInstanceOfDayAndTime(
          diaSemana: dia,
          hour: medicationHour,
          minute: medicationMinute,
        );

        if (isCompletedToday &&
            medicationDate.year == now.year &&
            medicationDate.month == now.month &&
            medicationDate.day == now.day) {
          medicationDate = medicationDate.add(const Duration(days: 7));
        }

        tz.TZDateTime alertDate = medicationDate.subtract(
          const Duration(minutes: 5),
        );

        // CORRECCIÓN 3: Arreglar el agujero negro de 5 minutos de las tareas recurrentes
        if (medicationDate.isBefore(now)) {
          // La tarea de hoy ya pasó
          medicationDate = medicationDate.add(const Duration(days: 7));
          alertDate = medicationDate.subtract(const Duration(minutes: 5));
        } else if (alertDate.isBefore(now)) {
          // Faltan menos de 5 minutos, la alerta previa sonará casi de inmediato (en 5 seg)
          alertDate = now.add(const Duration(seconds: 5));
        }

        final int notificationId = _notificationId(taskId, dia);
        debugPrint(
          '[NotificationService] Programando Alerta Semanal ID $notificationId ($medicationName para $patientName) el día $dia a las $alertDate',
        );

        await _notifications.zonedSchedule(
          id: notificationId,
          title: titleText,
          body: bodyText,
          scheduledDate: alertDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Recordatorios de tareas',
              channelDescription: 'Recordatorios automáticos 5 minutos antes.',
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

        // Mantenemos la alerta de retraso semanal usando + 5000000
        final int overdueId =
            (taskId.hashCode.abs() + dia.hashCode.abs() + 5000000) % 2147483647;
        debugPrint(
          '[NotificationService] Programando Alerta Semanal de Retraso ID $overdueId ($medicationName para $patientName) el día $dia a las $medicationDate',
        );

        await _notifications.zonedSchedule(
          id: overdueId,
          title: overdueTitle,
          body: overdueBody,
          scheduledDate: medicationDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Recordatorios de tareas',
              channelDescription: 'Recordatorios de tareas atrasadas.',
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
  }

  static Future<void> cancelMedicationReminder({
    required String taskId,
    required List<String> diasSemana,
  }) async {
    if (kIsWeb) return;
    await _cancelAllNotificationIdsForTask(taskId);
  }

  static Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  static Future<void> clearAllRemindersAndPreferences() async {
    if (kIsWeb) return;
    await cancelAllReminders();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final List<String> keysToRemove = keys
        .where((k) => k.startsWith('notified_'))
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    _previouslyScheduledTaskIds.clear();
    debugPrint(
      '[NotificationService] Limpiadas todas las alarmas y preferencias de notificación.',
    );
  }

  static Map<String, int>? _parseHourMinutePeriod(String value) {
    final String raw = value.trim().toUpperCase();

    // 1. Try 12-hour AM/PM pattern
    final RegExp regex12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$');
    final RegExpMatch? match12 = regex12.firstMatch(raw);

    if (match12 != null) {
      int hour = int.parse(match12.group(1)!);
      final int minute = int.parse(match12.group(2)!);
      final String period = match12.group(3)!;

      if (period == 'AM') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }

      return {'hour': hour, 'minute': minute};
    }

    // 2. Try 24-hour HH:MM pattern
    final RegExp regex24 = RegExp(r'^(\d{1,2}):(\d{2})$');
    final RegExpMatch? match24 = regex24.firstMatch(raw);

    if (match24 != null) {
      final int hour = int.parse(match24.group(1)!);
      final int minute = int.parse(match24.group(2)!);
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return {'hour': hour, 'minute': minute};
      }
    }

    return null;
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

  static bool isTaskScheduledForDate(Map<String, dynamic> data, DateTime date) {
    final String repeatType = data['repeatType']?.toString() ?? 'weekly_days';
    final DateTime targetDate = DateTime(date.year, date.month, date.day);

    DateTime startDate = targetDate;
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
        return targetDate.isAtSameMomentAs(startDate);

      case 'daily':
        return true;

      case 'every_n_days':
        final int repeatEveryDays = data['repeatEveryDays'] is int
            ? data['repeatEveryDays']
            : int.tryParse(data['repeatEveryDays']?.toString() ?? '') ?? 0;

        if (repeatEveryDays <= 0) return false;

        final int difference = targetDate.difference(startDate).inDays;
        return difference >= 0 && difference % repeatEveryDays == 0;

      case 'weekly_days':
      default:
        final List<String> diasSemana = List<String>.from(
          data['diasSemana'] ?? [],
        );
        final String dayName = _getDayNameInSpanish(targetDate);
        return diasSemana.map((d) => _normalizeString(d)).contains(dayName);
    }
  }

  static String _getDayNameInSpanish(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'lunes';
      case DateTime.tuesday:
        return 'martes';
      case DateTime.wednesday:
        return 'miercoles';
      case DateTime.thursday:
        return 'jueves';
      case DateTime.friday:
        return 'viernes';
      case DateTime.saturday:
        return 'sabado';
      case DateTime.sunday:
        return 'domingo';
      default:
        return 'lunes';
    }
  }

  static String _normalizeString(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  static Future<void> syncCaregiverReminders({
    required String uidCuidador,
    required List<QueryDocumentSnapshot> patientDocs,
  }) async {
    if (kIsWeb) return;

    try {
      debugPrint(
        '[NotificationService] Iniciando sincronización de alarmas para cuidador: $uidCuidador. Pacientes a procesar: ${patientDocs.length}',
      );

      final List<String> currentTaskIds = [];

      for (final doc in patientDocs) {
        final String patientId = doc.id;
        final String patientName =
            (doc.data() as Map<String, dynamic>)['name'] ??
            (doc.data() as Map<String, dynamic>)['nombre'] ??
            '';
        final List<String> asignaciones = List<String>.from(
          (doc.data() as Map<String, dynamic>)['asignaciones'] ?? [],
        );

        final List<String> assignedDays = [];
        for (final asignacion in asignaciones) {
          final parts = asignacion.split('_');
          if (parts.length == 2 && parts[1] == uidCuidador) {
            assignedDays.add(_normalizeString(parts[0]));
          }
        }

        debugPrint(
          '[NotificationService] Paciente: $patientName ($patientId). Días asignados al cuidador: $assignedDays',
        );
        if (assignedDays.isEmpty) {
          // Si no tiene días asignados, cancelar todos los recordatorios de sus tareas
          final QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
              .collection('pacientes')
              .doc(patientId)
              .collection('tareas')
              .get();
          for (final taskDoc in tasksSnapshot.docs) {
            final String taskId = taskDoc.id;
            await _cancelAllNotificationIdsForTask(taskId);
          }
          continue;
        }

        final QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
            .collection('pacientes')
            .doc(patientId)
            .collection('tareas')
            .get();

        for (final taskDoc in tasksSnapshot.docs) {
          final Map<String, dynamic> taskData =
              taskDoc.data() as Map<String, dynamic>;

          final String taskId = taskDoc.id;
          currentTaskIds.add(taskId);
          final String medicationName = taskData['title'] ?? '';
          final String time = taskData['time'] ?? '';
          final String category =
              (taskData['category'] ??
                      taskData['categoria'] ??
                      taskData['tipo'] ??
                      taskData['type'] ??
                      'Medicamentos')
                  .toString();
          final String repeatType =
              taskData['repeatType']?.toString() ?? 'weekly_days';

          final completedDates = taskData['completedDates'];
          final DateTime nowDt = DateTime.now();
          final String todayKey =
              '${nowDt.year}-${nowDt.month.toString().padLeft(2, '0')}-${nowDt.day.toString().padLeft(2, '0')}';
          final bool isCompletedToday =
              completedDates is Map<String, dynamic> &&
              completedDates[todayKey] == true;

          debugPrint(
            '[NotificationService] Tarea: $medicationName ($taskId), Categoría: $category, Repetición: $repeatType, Hora: $time, Completada hoy: $isCompletedToday',
          );

          if (isCompletedToday) {
            // Cancelar alertas para tareas ya completadas hoy
            await _cancelAllNotificationIdsForTask(taskId);
            continue;
          }

          if (repeatType == 'weekly_days' || repeatType == 'daily') {
            final List<String> taskDays = repeatType == 'daily'
                ? [
                    'lunes',
                    'martes',
                    'miercoles',
                    'jueves',
                    'viernes',
                    'sabado',
                    'domingo',
                  ]
                : List<String>.from(taskData['diasSemana'] ?? []);

            final List<String> daysToSchedule = taskDays
                .where((day) => assignedDays.contains(_normalizeString(day)))
                .toList();

            if (daysToSchedule.isNotEmpty) {
              debugPrint(
                '[NotificationService] Programando recordatorio para días: $daysToSchedule',
              );
              await scheduleMedicationReminder(
                taskId: taskId,
                patientName: patientName,
                medicationName: medicationName,
                time: time,
                diasSemana: daysToSchedule,
                isCompletedToday: isCompletedToday,
                category: category,
              );
            } else {
              // Tarea ya no asignada para el cuidador para este día
              await _cancelAllNotificationIdsForTask(taskId);
            }
          } else {
            for (int i = 0; i < 10; i++) {
              final DateTime date = DateTime.now().add(Duration(days: i));
              final String dayName = _getDayNameInSpanish(date);
              final String normalizedDayName = _normalizeString(dayName);

              if (assignedDays.contains(normalizedDayName) &&
                  isTaskScheduledForDate(taskData, date)) {
                final bool isCompletedOnDate =
                    completedDates is Map<String, dynamic> &&
                    completedDates['${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'] ==
                        true;

                if (isCompletedOnDate) {
                  final int notificationId =
                      (taskId.hashCode.abs() + date.day) % 2147483647;
                  final int overdueId =
                      (taskId.hashCode.abs() + date.day + 5000000) % 2147483647;
                  await _notifications.cancel(id: notificationId);
                  await _notifications.cancel(id: overdueId);
                  continue;
                }

                debugPrint(
                  '[NotificationService] Programando recordatorio específico para fecha: $date, Tarea: $medicationName, Completada: $isCompletedOnDate',
                );
                await scheduleMedicationReminder(
                  taskId: taskId,
                  patientName: patientName,
                  medicationName: medicationName,
                  time: time,
                  category: category,
                  isCompletedToday: isCompletedOnDate,
                  specificDate: date,
                );
              } else {
                final int notificationId =
                    (taskId.hashCode.abs() + date.day) % 2147483647;
                final int overdueId =
                    (taskId.hashCode.abs() + date.day + 5000000) % 2147483647;
                await _notifications.cancel(id: notificationId);
                await _notifications.cancel(id: overdueId);
              }
            }
          }
        }
      }

      // Cancelar tareas eliminadas de Firebase
      final deletedTaskIds = _previouslyScheduledTaskIds.difference(
        currentTaskIds.toSet(),
      );
      for (final taskId in deletedTaskIds) {
        await _cancelAllNotificationIdsForTask(taskId);
      }
      _previouslyScheduledTaskIds = currentTaskIds.toSet();
    } catch (e) {
      debugPrint('Error al sincronizar alarmas: $e');
    }
  }

  static Future<void> _cancelAllNotificationIdsForTask(String taskId) async {
    for (final day in [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ]) {
      final int notificationId = _notificationId(taskId, day);
      final int testId =
          (taskId.hashCode.abs() + day.hashCode.abs() + 1000000) % 2147483647;
      final int overdueId =
          (taskId.hashCode.abs() + day.hashCode.abs() + 5000000) % 2147483647;
      await _notifications.cancel(id: notificationId);
      await _notifications.cancel(id: testId);
      await _notifications.cancel(id: overdueId);
    }
    for (int i = 0; i < 10; i++) {
      final DateTime date = DateTime.now().add(Duration(days: i));
      final int notificationId =
          (taskId.hashCode.abs() + date.day) % 2147483647;
      final int overdueId =
          (taskId.hashCode.abs() + date.day + 5000000) % 2147483647;
      await _notifications.cancel(id: notificationId);
      await _notifications.cancel(id: overdueId);
    }
  }

  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'invitations_channel',
          'Invitaciones a Centros',
          channelDescription:
              'Notificaciones sobre invitaciones a nuevos centros.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }
}
