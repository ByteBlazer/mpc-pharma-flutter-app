typedef JsonMap = Map<String, dynamic>;

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.firmName,
    required this.city,
    required this.geoLatitude,
    required this.geoLongitude,
    this.slaHours = 24,
  });

  factory CustomerSummary.fromJson(JsonMap json) {
    return CustomerSummary(
      id: _stringValue(json['id']),
      firmName: _stringValue(json['firmName']),
      city: _stringValue(json['city']),
      geoLatitude: _stringValue(json['geoLatitude']),
      geoLongitude: _stringValue(json['geoLongitude']),
      slaHours: _positiveInt(json['slaHours']) ?? 24,
    );
  }

  factory CustomerSummary.fromCustomer(Customer customer) {
    return CustomerSummary(
      id: customer.id,
      firmName: customer.firmName,
      city: customer.city,
      geoLatitude: customer.geoLatitude,
      geoLongitude: customer.geoLongitude,
      slaHours: customer.slaHours,
    );
  }

  final String id;
  final String firmName;
  final String city;
  final String geoLatitude;
  final String geoLongitude;
  final int slaHours;

  double? get latitude => double.tryParse(geoLatitude.trim());

  double? get longitude => double.tryParse(geoLongitude.trim());

  bool get hasCoordinates => latitude != null && longitude != null;

  int get slaDays {
    final days = (slaHours / CustomerSla.hoursPerDay).round();
    return days.clamp(CustomerSla.dayOptions.first, CustomerSla.dayOptions.last);
  }

  String get slaDaysLabel => CustomerSla.daysLabel(slaDays);

  CustomerSummary copyWith({int? slaHours}) {
    return CustomerSummary(
      id: id,
      firmName: firmName,
      city: city,
      geoLatitude: geoLatitude,
      geoLongitude: geoLongitude,
      slaHours: slaHours ?? this.slaHours,
    );
  }

  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return '$id $firmName $city'.toLowerCase().contains(normalizedQuery);
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

class Customer {
  const Customer({
    required this.id,
    required this.firmName,
    required this.address,
    required this.city,
    required this.pincode,
    required this.phone,
    required this.geoLatitude,
    required this.geoLongitude,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.slaHours = 24,
  });

  factory Customer.fromJson(JsonMap json) {
    return Customer(
      id: _stringValue(json['id']),
      firmName: _stringValue(json['firmName']),
      address: _stringValue(json['address']),
      city: _stringValue(json['city']),
      pincode: _stringValue(json['pincode']),
      phone: _stringValue(json['phone']),
      geoLatitude: _stringValue(json['geoLatitude']),
      geoLongitude: _stringValue(json['geoLongitude']),
      createdAt: DateTime.tryParse(_stringValue(json['createdAt'])),
      lastUpdatedAt: DateTime.tryParse(_stringValue(json['lastUpdatedAt'])),
      slaHours: _positiveInt(json['slaHours']) ?? 24,
    );
  }

  final String id;
  final String firmName;
  final String address;
  final String city;
  final String pincode;
  final String phone;
  final String geoLatitude;
  final String geoLongitude;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final int slaHours;

  double? get latitude => double.tryParse(geoLatitude.trim());

  double? get longitude => double.tryParse(geoLongitude.trim());

  bool get hasCoordinates => latitude != null && longitude != null;

  int get slaDays {
    final days = (slaHours / CustomerSla.hoursPerDay).round();
    return days.clamp(CustomerSla.dayOptions.first, CustomerSla.dayOptions.last);
  }

  String get slaDaysLabel => CustomerSla.daysLabel(slaDays);

  Customer copyWith({int? slaHours}) {
    return Customer(
      id: id,
      firmName: firmName,
      address: address,
      city: city,
      pincode: pincode,
      phone: phone,
      geoLatitude: geoLatitude,
      geoLongitude: geoLongitude,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt,
      slaHours: slaHours ?? this.slaHours,
    );
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

/// Shared SLA day options for customer complaint tickets (1–7 days).
abstract final class CustomerSla {
  static const hoursPerDay = 24;
  static const dayOptions = [1, 2, 3, 4, 5, 6, 7];

  static int hoursFromDays(int days) => days * hoursPerDay;

  static String daysLabel(int days) => days == 1 ? '1 day' : '$days days';
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 1) return null;
  return parsed;
}
