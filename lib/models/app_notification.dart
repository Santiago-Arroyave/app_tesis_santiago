enum NotificationType {
  solicitudProyecto,
  asignacionActividad,
  nuevoReporte,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime dateTime;
  final bool isRead;
  final int? projectId;
  final String? projectNombre;
  final int? reportId;
  final String? reportTitulo;
  final String? extraStatus;
  final String? respuestaAdmin;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.dateTime,
    this.isRead = false,
    this.projectId,
    this.projectNombre,
    this.reportId,
    this.reportTitulo,
    this.extraStatus,
    this.respuestaAdmin,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? dateTime,
    bool? isRead,
    int? projectId,
    String? projectNombre,
    int? reportId,
    String? reportTitulo,
    String? extraStatus,
    String? respuestaAdmin,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      dateTime: dateTime ?? this.dateTime,
      isRead: isRead ?? this.isRead,
      projectId: projectId ?? this.projectId,
      projectNombre: projectNombre ?? this.projectNombre,
      reportId: reportId ?? this.reportId,
      reportTitulo: reportTitulo ?? this.reportTitulo,
      extraStatus: extraStatus ?? this.extraStatus,
      respuestaAdmin: respuestaAdmin ?? this.respuestaAdmin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'dateTime': dateTime.toIso8601String(),
      'isRead': isRead,
      'projectId': projectId,
      'projectNombre': projectNombre,
      'reportId': reportId,
      'reportTitulo': reportTitulo,
      'extraStatus': extraStatus,
      'respuestaAdmin': respuestaAdmin,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType parsedType = NotificationType.nuevoReporte;
    final typeStr = json['type']?.toString().toLowerCase() ?? '';
    if (typeStr.contains('solicitud') || typeStr.contains('proyecto_solicitud')) {
      parsedType = NotificationType.solicitudProyecto;
    } else if (typeStr.contains('actividad') || typeStr.contains('asignacion')) {
      parsedType = NotificationType.asignacionActividad;
    } else {
      parsedType = NotificationType.nuevoReporte;
    }

    return AppNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: parsedType,
      title: json['title']?.toString() ?? 'Notificación',
      message: json['message']?.toString() ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.tryParse(json['dateTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true,
      projectId: json['projectId'] is num ? (json['projectId'] as num).toInt() : int.tryParse(json['projectId']?.toString() ?? ''),
      projectNombre: json['projectNombre']?.toString(),
      reportId: json['reportId'] is num ? (json['reportId'] as num).toInt() : int.tryParse(json['reportId']?.toString() ?? ''),
      reportTitulo: json['reportTitulo']?.toString(),
      extraStatus: json['extraStatus']?.toString(),
      respuestaAdmin: json['respuestaAdmin']?.toString(),
    );
  }
}
