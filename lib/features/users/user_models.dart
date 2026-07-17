import '../../auth/app_role.dart';

typedef JsonMap = Map<String, dynamic>;

class UserDepartment {
  const UserDepartment({
    required this.id,
    required this.name,
  });

  factory UserDepartment.fromJson(JsonMap json) {
    return UserDepartment(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
    );
  }

  final String id;
  final String name;

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.mobile,
    required this.personName,
    required this.baseLocationId,
    required this.baseLocationName,
    required this.vehicleNbr,
    required this.isActive,
    required this.createdAt,
    required this.roles,
    this.departments = const [],
  });

  factory UserAccount.fromJson(JsonMap json) {
    return UserAccount(
      id: _stringValue(json['id']),
      mobile: _stringValue(json['mobile']),
      personName: _stringValue(json['personName']),
      baseLocationId: _stringValue(json['baseLocationId']),
      baseLocationName: _stringValue(json['baseLocationName']),
      vehicleNbr: _stringValue(json['vehicleNbr']),
      isActive: json['isActive'] == true,
      createdAt: DateTime.tryParse(_stringValue(json['createdAt'])),
      roles: _parseRoles(json['roles']),
      departments: _parseDepartments(json['departments']),
    );
  }

  final String id;
  final String mobile;
  final String personName;
  final String baseLocationId;
  final String baseLocationName;
  final String vehicleNbr;
  final bool isActive;
  final DateTime? createdAt;
  final List<AppRole> roles;
  final List<UserDepartment> departments;

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    final searchableText = [
      id,
      mobile,
      personName,
      baseLocationId,
      baseLocationName,
      vehicleNbr,
      isActive ? 'active' : 'inactive',
      ...roles.map((role) => role.tokenValue),
      ...roles.map((role) => role.label),
      ...departments.map((department) => department.name),
    ].join(' ').toLowerCase();
    return searchableText.contains(normalizedQuery);
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static List<AppRole> _parseRoles(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is JsonMap) return item['roleName']?.toString() ?? '';
          return item.toString();
        })
        .where((role) => role.isNotEmpty)
        .toAppRoles();
  }

  static List<UserDepartment> _parseDepartments(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<JsonMap>()
        .map(UserDepartment.fromJson)
        .where((department) => department.name.trim().isNotEmpty)
        .toList();
  }
}

class UserRoleOption {
  const UserRoleOption({required this.role, required this.description});

  factory UserRoleOption.fromJson(JsonMap json) {
    return UserRoleOption(
      role: AppRole.fromTokenValue(json['roleName']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
    );
  }

  final AppRole? role;
  final String description;
}

class BaseLocation {
  const BaseLocation({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory BaseLocation.fromJson(JsonMap json) {
    return BaseLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }

  final String id;
  final String name;
  final bool isActive;

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return '$id $name ${isActive ? 'active' : 'inactive'}'
        .toLowerCase()
        .contains(normalizedQuery);
  }
}

class BaseLocationSaveRequest {
  const BaseLocationSaveRequest({required this.name});

  final String name;

  JsonMap toJson() => {'name': name};
}

class UserAccountSaveRequest {
  const UserAccountSaveRequest({
    required this.mobile,
    required this.personName,
    required this.baseLocationId,
    required this.vehicleNbr,
    required this.isActive,
    required this.roles,
  });

  final String mobile;
  final String personName;
  final String baseLocationId;
  final String vehicleNbr;
  final bool isActive;
  final List<AppRole> roles;

  JsonMap toJson({bool includeIsActive = false}) {
    final trimmedVehicleNbr = vehicleNbr.trim();
    return {
      'mobile': mobile,
      'personName': personName,
      'baseLocationId': baseLocationId,
      'roles': roles.map((role) => role.tokenValue).toList(),
      if (includeIsActive) 'isActive': isActive,
      if (trimmedVehicleNbr.isNotEmpty) 'vehicleNbr': trimmedVehicleNbr,
    };
  }
}
