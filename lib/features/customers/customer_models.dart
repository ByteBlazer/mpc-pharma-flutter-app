typedef JsonMap = Map<String, dynamic>;

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.firmName,
    required this.city,
    required this.geoLatitude,
    required this.geoLongitude,
  });

  factory CustomerSummary.fromJson(JsonMap json) {
    return CustomerSummary(
      id: _stringValue(json['id']),
      firmName: _stringValue(json['firmName']),
      city: _stringValue(json['city']),
      geoLatitude: _stringValue(json['geoLatitude']),
      geoLongitude: _stringValue(json['geoLongitude']),
    );
  }

  final String id;
  final String firmName;
  final String city;
  final String geoLatitude;
  final String geoLongitude;

  double? get latitude => double.tryParse(geoLatitude.trim());

  double? get longitude => double.tryParse(geoLongitude.trim());

  bool get hasCoordinates => latitude != null && longitude != null;

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

  static String _stringValue(Object? value) => value?.toString() ?? '';
}
