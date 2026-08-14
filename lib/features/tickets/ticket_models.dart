import '../../constants/system_user_ids.dart';

typedef JsonMap = Map<String, dynamic>;

enum TicketType {
  internal('INTERNAL'),
  raisedForCustomer('RAISED_FOR_CUSTOMER');

  const TicketType(this.apiValue);
  final String apiValue;

  static TicketType? fromApi(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final type in values) {
      if (type.apiValue == normalized) return type;
    }
    return null;
  }
}

enum TicketStatus {
  open('OPEN'),
  assigned('ASSIGNED'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  invalid('INVALID'),
  closed('CLOSED');

  const TicketStatus(this.apiValue);
  final String apiValue;

  static TicketStatus? fromApi(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final status in values) {
      if (status.apiValue == normalized) return status;
    }
    return null;
  }

  String get label => switch (this) {
    TicketStatus.open => 'Open',
    TicketStatus.assigned => 'Assigned',
    TicketStatus.inProgress => 'In progress',
    TicketStatus.resolved => 'Resolved',
    TicketStatus.invalid => 'Invalid',
    TicketStatus.closed => 'Closed',
  };
}

enum TicketPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const TicketPriority(this.apiValue);
  final String apiValue;

  static TicketPriority? fromApi(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final priority in values) {
      if (priority.apiValue == normalized) return priority;
    }
    return null;
  }

  String get label => switch (this) {
    TicketPriority.low => 'Low',
    TicketPriority.medium => 'Medium',
    TicketPriority.high => 'High',
  };
}

class ComplaintCategory {
  const ComplaintCategory({
    required this.id,
    required this.name,
    required this.assignedDepartmentId,
    required this.assignedDepartmentName,
    required this.isActive,
  });

  factory ComplaintCategory.fromJson(JsonMap json) {
    return ComplaintCategory(
      id: _string(json['id']),
      name: _string(json['name']),
      assignedDepartmentId: _string(json['assignedDepartmentId']),
      assignedDepartmentName: _string(json['assignedDepartmentName']),
      isActive: json['isActive'] == true,
    );
  }

  final String id;
  final String name;
  final String assignedDepartmentId;
  final String assignedDepartmentName;
  final bool isActive;

  /// Shared day options for internal-category SLA (and ticket display helpers).
  static const slaHoursPerDay = 24;
  static const slaDayOptions = [1, 2, 3, 4, 5, 6, 7];

  static int slaHoursFromDays(int days) => days * slaHoursPerDay;

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      id,
      name,
      assignedDepartmentName,
      isActive ? 'active' : 'inactive',
    ].join(' ').toLowerCase().contains(normalized);
  }
}

class InternalCategory {
  const InternalCategory({
    required this.id,
    required this.name,
    required this.slaHours,
    required this.isActive,
  });

  factory InternalCategory.fromJson(JsonMap json) {
    return InternalCategory(
      id: _string(json['id']),
      name: _string(json['name']),
      slaHours: _positiveInt(json['slaHours']) ?? 24,
      isActive: json['isActive'] == true,
    );
  }

  final String id;
  final String name;
  final int slaHours;
  final bool isActive;

  static const slaHoursPerDay = ComplaintCategory.slaHoursPerDay;
  static const slaDayOptions = ComplaintCategory.slaDayOptions;

  int get slaDays {
    final days = (slaHours / slaHoursPerDay).round();
    return days.clamp(slaDayOptions.first, slaDayOptions.last);
  }

  String get slaDaysLabel => slaDays == 1 ? '1 day' : '$slaDays days';

  static int slaHoursFromDays(int days) => days * slaHoursPerDay;

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      id,
      name,
      '$slaHours',
      slaDaysLabel,
      isActive ? 'active' : 'inactive',
    ].join(' ').toLowerCase().contains(normalized);
  }
}

class TicketAttachmentInitResponse {
  const TicketAttachmentInitResponse({
    required this.attachmentId,
    required this.uploadUrl,
    required this.expiresIn,
  });

  factory TicketAttachmentInitResponse.fromJson(JsonMap json) {
    return TicketAttachmentInitResponse(
      attachmentId: _string(json['attachmentId']),
      uploadUrl: _string(json['uploadUrl']),
      expiresIn: int.tryParse(_string(json['expiresIn'])) ?? 900,
    );
  }

  final String attachmentId;
  final String uploadUrl;
  final int expiresIn;
}

class TicketAttachmentDownload {
  const TicketAttachmentDownload({
    required this.downloadUrl,
    required this.expiresIn,
    required this.originalFileName,
    required this.mimeType,
    required this.fileSize,
  });

  factory TicketAttachmentDownload.fromJson(JsonMap json) {
    return TicketAttachmentDownload(
      downloadUrl: _string(json['downloadUrl']),
      expiresIn: int.tryParse(_string(json['expiresIn'])) ?? 900,
      originalFileName: _string(json['originalFileName']),
      mimeType: _string(json['mimeType']),
      fileSize: int.tryParse(_string(json['fileSize'])) ?? 0,
    );
  }

  final String downloadUrl;
  final int expiresIn;
  final String originalFileName;
  final String mimeType;
  final int fileSize;
}

class TicketAttachment {
  const TicketAttachment({
    required this.attachmentId,
    required this.attachmentContext,
    required this.commentId,
    required this.originalFileName,
    required this.mimeType,
    required this.fileSize,
    required this.createdBy,
    required this.createdAt,
  });

  factory TicketAttachment.fromJson(JsonMap json) {
    return TicketAttachment(
      attachmentId: _string(json['attachmentId']),
      attachmentContext: _string(json['attachmentContext']),
      commentId: json['commentId']?.toString(),
      originalFileName: _string(json['originalFileName']),
      mimeType: _string(json['mimeType']),
      fileSize: int.tryParse(_string(json['fileSize'])) ?? 0,
      createdBy: _string(json['createdBy']),
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
    );
  }

  final String attachmentId;
  final String attachmentContext;
  final String? commentId;
  final String originalFileName;
  final String mimeType;
  final int fileSize;
  final String createdBy;
  final DateTime? createdAt;

  bool get isAudio => mimeType.startsWith('audio/');
}

class TicketComment {
  const TicketComment({
    required this.id,
    required this.comment,
    required this.createdByAppUserId,
    required this.createdByName,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.lastUpdatedByAppUserId,
  });

  factory TicketComment.fromJson(JsonMap json) {
    return TicketComment(
      id: _string(json['id']),
      comment: _string(json['comment']),
      createdByAppUserId: _string(json['createdByAppUserId']),
      createdByName: _string(json['createdByName']),
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
      lastUpdatedAt: DateTime.tryParse(_string(json['lastUpdatedAt'])),
      lastUpdatedByAppUserId: _string(json['lastUpdatedByAppUserId']),
    );
  }

  final String id;
  final String comment;
  final String createdByAppUserId;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final String lastUpdatedByAppUserId;
}

class TicketActivity {
  const TicketActivity({
    required this.id,
    required this.activityType,
    required this.message,
    required this.oldValue,
    required this.newValue,
    required this.createdByAppUserId,
    required this.createdByName,
    required this.createdAt,
  });

  factory TicketActivity.fromJson(JsonMap json) {
    return TicketActivity(
      id: _string(json['id']),
      activityType: _string(json['activityType']),
      message: _string(json['message']),
      oldValue: json['oldValue']?.toString(),
      newValue: json['newValue']?.toString(),
      createdByAppUserId: _string(json['createdByAppUserId']),
      createdByName: _string(json['createdByName']),
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
    );
  }

  final String id;
  final String activityType;
  final String message;
  final String? oldValue;
  final String? newValue;
  final String createdByAppUserId;
  final String createdByName;
  final DateTime? createdAt;
}

class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.status,
    required this.priority,
    required this.ticketType,
    required this.subject,
    required this.assignedDepartmentId,
    required this.assignedDepartmentName,
    required this.assigneeAppUserId,
    required this.assigneeName,
    required this.createdBy,
    required this.customerFirmName,
    required this.createdByName,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.ticketComplaintCategoryName = '',
    this.ticketInternalCategoryName = '',
    this.relatedDocId = '',
    this.slaHours,
    this.raisedByCustomer,
    this.slaMissed = false,
  });

  factory TicketSummary.fromJson(JsonMap json) {
    return TicketSummary(
      id: _string(json['id']),
      status:
          TicketStatus.fromApi(_string(json['status'])) ?? TicketStatus.open,
      priority:
          TicketPriority.fromApi(_string(json['priority'])) ??
          TicketPriority.medium,
      ticketType:
          TicketType.fromApi(_string(json['ticketType'])) ??
          TicketType.raisedForCustomer,
      subject: _string(json['subject']),
      assignedDepartmentId: _string(json['assignedDepartmentId']),
      assignedDepartmentName: _string(json['assignedDepartmentName']),
      assigneeAppUserId: _string(json['assigneeAppUserId']),
      assigneeName: _string(json['assigneeName']),
      createdBy: _string(json['createdBy']),
      customerFirmName: _string(json['customerFirmName']),
      createdByName: _string(json['createdByName']),
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
      lastUpdatedAt: DateTime.tryParse(_string(json['lastUpdatedAt'])),
      ticketComplaintCategoryName: _string(json['ticketComplaintCategoryName']),
      ticketInternalCategoryName: _string(json['ticketInternalCategoryName']),
      relatedDocId: _string(json['relatedDocId']),
      slaHours: _positiveInt(json['slaHours']),
      raisedByCustomer: _optionalBool(json['raisedByCustomer']),
      slaMissed: json['slaMissed'] == true,
    );
  }

  final String id;
  final TicketStatus status;
  final TicketPriority priority;
  final TicketType ticketType;
  final String subject;
  final String assignedDepartmentId;
  final String assignedDepartmentName;
  final String assigneeAppUserId;
  final String assigneeName;
  final String createdBy;
  final String customerFirmName;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final String ticketComplaintCategoryName;
  final String ticketInternalCategoryName;
  final String relatedDocId;
  final int? slaHours;

  /// Customer JWT only: true = self-raised, false = company-raised.
  final bool? raisedByCustomer;

  /// Employee list only: ticket past its category SLA.
  final bool slaMissed;

  bool get isRaisedByCustomer => raisedByCustomer == true;

  bool get isCustomerTicket => ticketType == TicketType.raisedForCustomer;

  bool get hasRelatedDoc => relatedDocId.trim().isNotEmpty;

  String get categoryDisplayLabel {
    final name = (ticketType == TicketType.internal
            ? ticketInternalCategoryName
            : ticketComplaintCategoryName)
        .trim();
    return _categoryNameWithSla(name: name, slaHours: slaHours);
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      id,
      status.label,
      priority.label,
      ticketType.apiValue,
      subject,
      assignedDepartmentName,
      assigneeName,
      customerFirmName,
      createdByName,
      ticketComplaintCategoryName,
      ticketInternalCategoryName,
      relatedDocId,
    ].join(' ').toLowerCase().contains(normalized);
  }
}

class TicketDetail {
  const TicketDetail({
    required this.id,
    required this.ticketType,
    required this.status,
    required this.priority,
    required this.subject,
    required this.description,
    required this.resolutionSummary,
    required this.invalidationReason,
    required this.raisedForCustomerId,
    required this.raisedForCustomerName,
    required this.createdBy,
    required this.createdByName,
    required this.createdByCustomerId,
    required this.raisedForAppUserId,
    required this.raisedForAppUserName,
    required this.assignedDepartmentId,
    required this.assignedDepartmentName,
    required this.assigneeAppUserId,
    required this.assigneeName,
    required this.ticketComplaintCategoryId,
    required this.ticketComplaintCategoryName,
    required this.ticketInternalCategoryId,
    required this.ticketInternalCategoryName,
    this.slaHours,
    required this.attachments,
    required this.comments,
    required this.activity,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.lastUpdatedBy,
    required this.isEmployeeView,
    this.relatedDocId = '',
    this.raisedByCustomer,
  });

  factory TicketDetail.fromJson(JsonMap json, {required bool isEmployeeView}) {
    final attachmentsJson = json['attachments'];
    final commentsJson = json['comments'];
    final activityJson = json['activity'];

    return TicketDetail(
      id: _string(json['id']),
      ticketType:
          TicketType.fromApi(_string(json['ticketType'])) ??
          TicketType.raisedForCustomer,
      status:
          TicketStatus.fromApi(_string(json['status'])) ?? TicketStatus.open,
      priority:
          TicketPriority.fromApi(_string(json['priority'])) ??
          TicketPriority.medium,
      subject: _string(json['subject']),
      description: _string(json['description']),
      resolutionSummary: _string(json['resolutionSummary']),
      invalidationReason: _string(json['invalidationReason']),
      raisedForCustomerId: _string(json['raisedForCustomerId']),
      raisedForCustomerName: _string(json['raisedForCustomerName']),
      createdBy: _string(json['createdBy']),
      createdByName: _firstNonEmptyString(json, const [
        'createdByName',
        'createdByPersonName',
        'creatorName',
        'raisedByName',
      ]),
      createdByCustomerId: _string(json['createdByCustomerId']),
      raisedForAppUserId: _string(json['raisedForAppUserId']),
      raisedForAppUserName: _firstNonEmptyString(json, const [
        'raisedForAppUserName',
        'raisedForAppUserPersonName',
      ]),
      assignedDepartmentId: _string(json['assignedDepartmentId']),
      assignedDepartmentName: _string(json['assignedDepartmentName']),
      assigneeAppUserId: _string(json['assigneeAppUserId']),
      assigneeName: _string(json['assigneeName']),
      ticketComplaintCategoryId: _string(json['ticketComplaintCategoryId']),
      ticketComplaintCategoryName: _string(json['ticketComplaintCategoryName']),
      ticketInternalCategoryId: _string(json['ticketInternalCategoryId']),
      ticketInternalCategoryName: _string(json['ticketInternalCategoryName']),
      relatedDocId: _string(json['relatedDocId']),
      slaHours: _positiveInt(json['slaHours']),
      attachments: attachmentsJson is List
          ? attachmentsJson
                .whereType<JsonMap>()
                .map(TicketAttachment.fromJson)
                .toList()
          : const [],
      comments: commentsJson is List
          ? commentsJson
                .whereType<JsonMap>()
                .map(TicketComment.fromJson)
                .toList()
          : const [],
      activity: activityJson is List
          ? activityJson
                .whereType<JsonMap>()
                .map(TicketActivity.fromJson)
                .toList()
          : const [],
      createdAt: DateTime.tryParse(_string(json['createdAt'])),
      lastUpdatedAt: DateTime.tryParse(_string(json['lastUpdatedAt'])),
      lastUpdatedBy: _string(json['lastUpdatedBy']),
      isEmployeeView: isEmployeeView,
      raisedByCustomer: _optionalBool(json['raisedByCustomer']),
    );
  }

  final String id;
  final TicketType ticketType;
  final TicketStatus status;
  final TicketPriority priority;
  final String subject;
  final String description;
  final String resolutionSummary;
  final String invalidationReason;
  final String raisedForCustomerId;
  final String raisedForCustomerName;
  final String createdBy;
  final String createdByName;
  final String createdByCustomerId;
  final String raisedForAppUserId;
  final String raisedForAppUserName;
  final String assignedDepartmentId;
  final String assignedDepartmentName;
  final String assigneeAppUserId;
  final String assigneeName;
  final String ticketComplaintCategoryId;
  final String ticketComplaintCategoryName;
  final String ticketInternalCategoryId;
  final String ticketInternalCategoryName;
  final int? slaHours;
  final List<TicketAttachment> attachments;
  final List<TicketComment> comments;
  final List<TicketActivity> activity;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final String lastUpdatedBy;
  final bool isEmployeeView;
  final String relatedDocId;

  /// Customer JWT only: true = self-raised, false = company-raised.
  final bool? raisedByCustomer;

  bool get isRaisedByCustomer => raisedByCustomer == true;

  bool get hasRelatedDoc => relatedDocId.trim().isNotEmpty;

  String get categoryDisplayLabel {
    final name = (ticketType == TicketType.internal
            ? ticketInternalCategoryName
            : ticketComplaintCategoryName)
        .trim();
    return _categoryNameWithSla(name: name, slaHours: slaHours);
  }

  bool get isClosed => status == TicketStatus.closed;
  bool get isTerminal =>
      status == TicketStatus.resolved ||
      status == TicketStatus.invalid ||
      status == TicketStatus.closed;

  /// Dept/assignee may be reassigned for any status except CLOSED.
  bool get canReassignByStatus => status != TicketStatus.closed;

  /// Reassigning a resolved/invalid ticket reopens it via the assign API.
  bool get reassignReopensTicket =>
      status == TicketStatus.resolved || status == TicketStatus.invalid;

  /// Customer may add files only on self-raised complaints that are still open.
  bool get canCustomerAddAttachments =>
      isRaisedByCustomer &&
      status != TicketStatus.resolved &&
      status != TicketStatus.invalid &&
      status != TicketStatus.closed;

  /// Customer self-service complaint (`createdBy` is the system user).
  bool get isCustomerSelfService => createdBy == sytemAppUserId;

  /// Subject/description may be edited only by the employee creator while
  /// the ticket is OPEN or ASSIGNED. Never for customer self-service tickets.
  bool canEditSubjectAndDescription(String? currentEmployeeId) {
    if (isCustomerSelfService) return false;
    if (currentEmployeeId == null || currentEmployeeId.isEmpty) return false;
    if (createdBy != currentEmployeeId) return false;
    return status == TicketStatus.open || status == TicketStatus.assigned;
  }

  /// App-user id of the employee who raised the ticket, if any.
  String get raisedByEmployeeId {
    if (isCustomerSelfService) return '';
    if (createdBy.trim().isNotEmpty) return createdBy.trim();
    if (ticketType == TicketType.internal) {
      return raisedForAppUserId.trim();
    }
    return '';
  }

  /// Display name for the primary "Raised by" line (never a raw user id).
  /// Customer self-service → customer firm name; otherwise → employee name.
  String get raisedByLabel {
    if (isCustomerSelfService) {
      return raisedForCustomerName.trim();
    }
    final fromCreatedBy = createdByName.trim();
    if (fromCreatedBy.isNotEmpty) return fromCreatedBy;
    if (ticketType == TicketType.internal) {
      final fromRaisedFor = raisedForAppUserName.trim();
      if (fromRaisedFor.isNotEmpty) return fromRaisedFor;
    }
    return '';
  }

  /// Customer firm name when an employee raised on behalf of a customer.
  String get raisedOnBehalfOfCustomerLabel {
    if (ticketType != TicketType.raisedForCustomer) return '';
    if (isCustomerSelfService) return '';
    return raisedForCustomerName.trim();
  }
}

class PendingTicketAttachment {
  const PendingTicketAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.isAudio = false,
  });

  final String attachmentId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final bool isAudio;
}

String _string(Object? value) => value?.toString() ?? '';

String _categoryNameWithSla({required String name, required int? slaHours}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final hours = slaHours;
  if (hours == null || hours < 1) return trimmed;
  final days = (hours / ComplaintCategory.slaHoursPerDay).round();
  if (days < 1) return trimmed;
  final daysLabel = days == 1 ? '1 day' : '$days days';
  return '$trimmed | SLA: $daysLabel';
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(_string(value));
  if (parsed == null || parsed < 1) return null;
  return parsed;
}

String _firstNonEmptyString(JsonMap json, List<String> keys) {
  for (final key in keys) {
    final value = _string(json[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool? _optionalBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}
