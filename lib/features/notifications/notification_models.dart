typedef JsonMap = Map<String, dynamic>;

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientAppUserId,
    required this.module,
    required this.referenceId,
    required this.eventType,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(JsonMap json) {
    return AppNotification(
      id: _string(json['id']),
      recipientAppUserId: _string(json['recipientAppUserId']),
      module: _string(json['module']).toUpperCase(),
      referenceId: _string(json['referenceId']),
      eventType: _string(json['eventType']),
      message: _string(json['message']),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
    );
  }

  final String id;
  final String recipientAppUserId;
  final String module;
  final String referenceId;
  final String eventType;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  bool get canNavigate {
    if (referenceId.trim().isEmpty) return false;
    return module == 'TICKET';
  }
}

String _string(Object? value) => value?.toString() ?? '';
