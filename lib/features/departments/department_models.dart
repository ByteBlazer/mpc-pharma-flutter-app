typedef JsonMap = Map<String, dynamic>;

class DepartmentUser {
  const DepartmentUser({
    required this.id,
    required this.personName,
    required this.mobile,
    required this.isDepartmentLead,
    required this.isTicketTriager,
  });

  factory DepartmentUser.fromJson(JsonMap json) {
    return DepartmentUser(
      id: _stringValue(json['id']),
      personName: _stringValue(json['personName']),
      mobile: _stringValue(json['mobile']),
      isDepartmentLead: json['isDepartmentLead'] == true,
      isTicketTriager: json['isTicketTriager'] == true,
    );
  }

  final String id;
  final String personName;
  final String mobile;
  final bool isDepartmentLead;
  final bool isTicketTriager;

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.isActive,
    required this.users,
    required this.createdAt,
    required this.createdBy,
    required this.lastUpdatedAt,
    required this.lastUpdatedBy,
  });

  factory Department.fromJson(JsonMap json) {
    final usersJson = json['users'];
    return Department(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      isActive: json['isActive'] == true,
      users: usersJson is List
          ? usersJson
                .whereType<JsonMap>()
                .map(DepartmentUser.fromJson)
                .toList()
          : const [],
      createdAt: DateTime.tryParse(_stringValue(json['createdAt'])),
      createdBy: _stringValue(json['createdBy']),
      lastUpdatedAt: DateTime.tryParse(_stringValue(json['lastUpdatedAt'])),
      lastUpdatedBy: _stringValue(json['lastUpdatedBy']),
    );
  }

  final String id;
  final String name;
  final bool isActive;
  final List<DepartmentUser> users;
  final DateTime? createdAt;
  final String createdBy;
  final DateTime? lastUpdatedAt;
  final String lastUpdatedBy;

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final searchableText = [
      id,
      name,
      isActive ? 'active' : 'inactive',
      ...users.map((user) => user.id),
      ...users.map((user) => user.personName),
      ...users.map((user) => user.mobile),
      ...users.map((user) => user.isDepartmentLead ? 'lead' : ''),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

class DepartmentSaveRequest {
  const DepartmentSaveRequest({
    required this.name,
    required this.userIds,
    required this.isActive,
  });

  final String name;
  final List<String> userIds;
  final bool isActive;

  JsonMap toJson() => {
    'name': name,
    'userIds': userIds,
    'isActive': isActive,
  };
}
