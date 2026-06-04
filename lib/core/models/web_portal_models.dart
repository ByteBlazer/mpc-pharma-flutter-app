class WebPortalUserRole {
  WebPortalUserRole({required this.roleName});

  final String roleName;

  factory WebPortalUserRole.fromJson(Map<String, dynamic> json) =>
      WebPortalUserRole(roleName: json['roleName']?.toString() ?? '');
}

class WebPortalUser {
  WebPortalUser({
    required this.id,
    required this.personName,
    required this.mobile,
    required this.vehicleNbr,
    required this.isActive,
    required this.createdAt,
    required this.roles,
    required this.baseLocationId,
    required this.baseLocationName,
  });

  final String id;
  final String personName;
  final String mobile;
  final String vehicleNbr;
  final bool isActive;
  final DateTime createdAt;
  final List<WebPortalUserRole> roles;
  final String baseLocationId;
  final String baseLocationName;

  factory WebPortalUser.fromJson(Map<String, dynamic> json) => WebPortalUser(
        id: json['id']?.toString() ?? '',
        personName: json['personName']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        vehicleNbr: json['vehicleNbr']?.toString() ?? '',
        isActive: json['isActive'] == true,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        roles: (json['roles'] as List?)
                ?.map(
                  (e) => WebPortalUserRole.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        baseLocationId: json['baseLocationId']?.toString() ?? '',
        baseLocationName: json['baseLocationName']?.toString() ?? '',
      );
}

class WebPortalBaseLocation {
  WebPortalBaseLocation({required this.id, required this.name});

  final String id;
  final String name;

  factory WebPortalBaseLocation.fromJson(Map<String, dynamic> json) =>
      WebPortalBaseLocation(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class WebPortalSetting {
  WebPortalSetting({this.settingName, this.settingValue});

  final String? settingName;
  final String? settingValue;

  factory WebPortalSetting.fromJson(Map<String, dynamic> json) =>
      WebPortalSetting(
        settingName: json['settingName']?.toString(),
        settingValue: json['settingValue']?.toString(),
      );
}

class WebPortalTrip {
  WebPortalTrip({
    required this.tripId,
    required this.createdBy,
    required this.driverName,
    required this.driverPhoneNumber,
    required this.vehicleNumber,
    required this.status,
    required this.route,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.startedAt,
    this.driverLastKnownLatitude,
    this.driverLastKnownLongitude,
    this.docGroups,
  });

  final int tripId;
  final String createdBy;
  final String driverName;
  final String driverPhoneNumber;
  final String vehicleNumber;
  final String status;
  final String route;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final DateTime startedAt;
  final String? driverLastKnownLatitude;
  final String? driverLastKnownLongitude;
  final List<WebPortalDocGroup>? docGroups;

  factory WebPortalTrip.fromJson(Map<String, dynamic> json) => WebPortalTrip(
        tripId: (json['tripId'] as num?)?.toInt() ?? 0,
        createdBy: json['createdBy']?.toString() ?? '',
        driverName: json['driverName']?.toString() ?? '',
        driverPhoneNumber: json['driverPhoneNumber']?.toString() ?? '',
        vehicleNumber: json['vehicleNumber']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        route: json['route']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastUpdatedAt:
            DateTime.tryParse(json['lastUpdatedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        driverLastKnownLatitude:
            json['driverLastKnownLatitude']?.toString(),
        driverLastKnownLongitude:
            json['driverLastKnownLongitude']?.toString(),
        docGroups: (json['docGroups'] as List?)
            ?.map((e) => WebPortalDocGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WebPortalDocGroup {
  WebPortalDocGroup({
    required this.heading,
    required this.showDropOffButton,
    required this.docs,
  });

  final String heading;
  final bool showDropOffButton;
  final List<WebPortalDoc> docs;

  factory WebPortalDocGroup.fromJson(Map<String, dynamic> json) =>
      WebPortalDocGroup(
        heading: json['heading']?.toString() ?? '',
        showDropOffButton: json['showDropOffButton'] == true,
        docs: (json['docs'] as List?)
                ?.map((e) => WebPortalDoc.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class WebPortalDoc {
  WebPortalDoc({
    required this.id,
    required this.status,
    required this.customerId,
    required this.customerFirmName,
    required this.customerAddress,
    required this.customerCity,
    required this.customerPhone,
    this.customerGeoLatitude,
    this.customerGeoLongitude,
    this.lot,
    this.docAmount,
    this.comment,
  });

  final String id;
  final String status;
  final String customerId;
  final String customerFirmName;
  final String customerAddress;
  final String customerCity;
  final String customerPhone;
  final String? customerGeoLatitude;
  final String? customerGeoLongitude;
  final String? lot;
  final String? docAmount;
  final String? comment;

  factory WebPortalDoc.fromJson(Map<String, dynamic> json) => WebPortalDoc(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        customerId: json['customerId']?.toString() ?? '',
        customerFirmName: json['customerFirmName']?.toString() ?? '',
        customerAddress: json['customerAddress']?.toString() ?? '',
        customerCity: json['customerCity']?.toString() ?? '',
        customerPhone: json['customerPhone']?.toString() ?? '',
        customerGeoLatitude: json['customerGeoLatitude']?.toString(),
        customerGeoLongitude: json['customerGeoLongitude']?.toString(),
        lot: json['lot']?.toString(),
        docAmount: json['docAmount']?.toString(),
        comment: json['comment']?.toString(),
      );
}

class WebPortalAllTripsResponse {
  WebPortalAllTripsResponse({required this.trips});

  final List<WebPortalTrip> trips;

  factory WebPortalAllTripsResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalAllTripsResponse(
        trips: (json['trips'] as List?)
                ?.map((e) => WebPortalTrip.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class WebPortalDocSearchResponse {
  WebPortalDocSearchResponse({
    required this.docId,
    required this.docStatus,
    this.tripId,
    this.tripStatus,
  });

  final String docId;
  final String docStatus;
  final int? tripId;
  final String? tripStatus;

  factory WebPortalDocSearchResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalDocSearchResponse(
        docId: json['docId']?.toString() ?? '',
        docStatus: json['docStatus']?.toString() ?? '',
        tripId: (json['tripId'] as num?)?.toInt(),
        tripStatus: json['tripStatus']?.toString(),
      );
}

class WebPortalDeliveryStatusResponse {
  WebPortalDeliveryStatusResponse({
    required this.success,
    this.comment,
    this.signature,
    this.deliveredAt,
  });

  final bool success;
  final String? comment;
  final String? signature;
  final DateTime? deliveredAt;

  factory WebPortalDeliveryStatusResponse.fromJson(
    Map<String, dynamic> json,
  ) =>
      WebPortalDeliveryStatusResponse(
        success: json['success'] == true,
        comment: json['comment']?.toString(),
        signature: json['signature']?.toString(),
        deliveredAt: DateTime.tryParse(json['deliveredAt']?.toString() ?? ''),
      );
}

class WebPortalLightweightCustomer {
  WebPortalLightweightCustomer({
    required this.id,
    required this.firmName,
    this.city,
  });

  final String id;
  final String firmName;
  final String? city;

  factory WebPortalLightweightCustomer.fromJson(Map<String, dynamic> json) =>
      WebPortalLightweightCustomer(
        id: json['id']?.toString() ?? '',
        firmName: json['firmName']?.toString() ?? '',
        city: json['city']?.toString(),
      );
}

class WebPortalDeliveryReportItem {
  WebPortalDeliveryReportItem({
    required this.docId,
    required this.status,
    required this.docDate,
    required this.tripId,
    this.comment,
    this.firmName,
    this.address,
    this.city,
    this.createdByPersonName,
    this.createdByLocation,
    this.driverName,
    this.vehicleNbr,
    this.route,
    this.originWarehouse,
    this.lastUpdatedAt,
  });

  final String docId;
  final String status;
  final String docDate;
  final int tripId;
  final String? comment;
  final String? firmName;
  final String? address;
  final String? city;
  final String? createdByPersonName;
  final String? createdByLocation;
  final String? driverName;
  final String? vehicleNbr;
  final String? route;
  final String? originWarehouse;
  final String? lastUpdatedAt;

  factory WebPortalDeliveryReportItem.fromJson(Map<String, dynamic> json) =>
      WebPortalDeliveryReportItem(
        docId: json['docId']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        docDate: json['docDate']?.toString() ?? '',
        tripId: (json['tripId'] as num?)?.toInt() ?? 0,
        comment: json['comment']?.toString(),
        firmName: json['firmName']?.toString(),
        address: json['address']?.toString(),
        city: json['city']?.toString(),
        createdByPersonName: json['createdByPersonName']?.toString(),
        createdByLocation: json['createdByLocation']?.toString(),
        driverName: json['driverName']?.toString(),
        vehicleNbr: json['vehicleNbr']?.toString(),
        route: json['route']?.toString(),
        originWarehouse: json['originWarehouse']?.toString(),
        lastUpdatedAt: json['lastUpdatedAt']?.toString(),
      );
}

class WebPortalDeliveryReportResponse {
  WebPortalDeliveryReportResponse({
    required this.data,
    required this.totalRecords,
  });

  final List<WebPortalDeliveryReportItem> data;
  final int totalRecords;

  factory WebPortalDeliveryReportResponse.fromJson(
    Map<String, dynamic> json,
  ) =>
      WebPortalDeliveryReportResponse(
        data: (json['data'] as List?)
                ?.map(
                  (e) => WebPortalDeliveryReportItem.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [],
        totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      );
}

class WebPortalDeliveryReportFilters {
  WebPortalDeliveryReportFilters({
    this.fromDate,
    this.toDate,
    this.docId,
    this.customerId,
    this.customerCity,
    this.originWarehouse,
    this.tripId,
    this.driverUserId,
    this.route,
    this.tripStartLocation,
  });

  final String? fromDate;
  final String? toDate;
  final String? docId;
  final String? customerId;
  final String? customerCity;
  final String? originWarehouse;
  final int? tripId;
  final String? driverUserId;
  final String? route;
  final String? tripStartLocation;

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    void add(String key, Object? value) {
      if (value == null) return;
      final s = value.toString();
      if (s.isEmpty) return;
      params[key] = s;
    }

    add('fromDate', fromDate);
    add('toDate', toDate);
    add('docId', docId);
    add('customerId', customerId);
    add('customerCity', customerCity);
    add('originWarehouse', originWarehouse);
    add('tripId', tripId);
    add('driverUserId', driverUserId);
    add('route', route);
    add('tripStartLocation', tripStartLocation);
    return params;
  }
}

class WebPortalSignatureResponse {
  WebPortalSignatureResponse({
    required this.signature,
    required this.lastUpdatedAt,
  });

  final String signature;
  final String lastUpdatedAt;

  factory WebPortalSignatureResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalSignatureResponse(
        signature: json['signature']?.toString() ?? '',
        lastUpdatedAt: json['lastUpdatedAt']?.toString() ?? '',
      );
}

class WebPortalBackupFile {
  WebPortalBackupFile({
    required this.filename,
    required this.size,
    required this.lastModified,
  });

  final String filename;
  final int size;
  final String lastModified;

  factory WebPortalBackupFile.fromJson(Map<String, dynamic> json) =>
      WebPortalBackupFile(
        filename: json['filename']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        lastModified: json['lastModified']?.toString() ?? '',
      );
}

class WebPortalBackupListResponse {
  WebPortalBackupListResponse({required this.backups});

  final List<WebPortalBackupFile> backups;

  factory WebPortalBackupListResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalBackupListResponse(
        backups: (json['backups'] as List?)
                ?.map(
                  (e) =>
                      WebPortalBackupFile.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
      );
}

class WebPortalCreateBackupResponse {
  WebPortalCreateBackupResponse({this.filename, this.message});

  final String? filename;
  final String? message;

  factory WebPortalCreateBackupResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalCreateBackupResponse(
        filename: json['filename']?.toString(),
        message: json['message']?.toString(),
      );
}

class WebPortalUserFormData {
  WebPortalUserFormData({
    required this.mobile,
    required this.personName,
    required this.baseLocationId,
    required this.vehicleNbr,
    required this.roles,
    this.isActive = true,
  });

  final String mobile;
  final String personName;
  final String baseLocationId;
  final String vehicleNbr;
  final List<String> roles;
  final bool isActive;

  Map<String, dynamic> toJson({bool includeIsActive = true}) {
    final map = <String, dynamic>{
      'mobile': mobile,
      'personName': personName,
      'baseLocationId': baseLocationId,
      'vehicleNbr': vehicleNbr,
      'roles': roles,
    };
    if (includeIsActive) {
      map['isActive'] = isActive;
    }
    return map;
  }
}

class WebPortalDocTrackingLocation {
  WebPortalDocTrackingLocation({
    required this.latitude,
    required this.longitude,
    this.receivedAt,
  });

  final String latitude;
  final String longitude;
  final DateTime? receivedAt;

  factory WebPortalDocTrackingLocation.fromJson(Map<String, dynamic> json) =>
      WebPortalDocTrackingLocation(
        latitude: json['latitude']?.toString() ?? '',
        longitude: json['longitude']?.toString() ?? '',
        receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
      );
}

class WebPortalDocTrackingResponse {
  WebPortalDocTrackingResponse({
    required this.success,
    this.message,
    this.docId,
    this.docAmount,
    this.customerFirmName,
    this.customerAddress,
    this.customerCity,
    this.customerPincode,
    this.status,
    this.comment,
    this.deliveryTimestamp,
    this.customerLocation,
    this.driverLastKnownLocation,
    this.numEnrouteCustomers,
    this.eta,
  });

  final bool success;
  final String? message;
  final String? docId;
  final String? docAmount;
  final String? customerFirmName;
  final String? customerAddress;
  final String? customerCity;
  final String? customerPincode;
  final String? status;
  final String? comment;
  final DateTime? deliveryTimestamp;
  final WebPortalDocTrackingLocation? customerLocation;
  final WebPortalDocTrackingLocation? driverLastKnownLocation;
  final int? numEnrouteCustomers;
  final double? eta;

  factory WebPortalDocTrackingResponse.fromJson(Map<String, dynamic> json) =>
      WebPortalDocTrackingResponse(
        success: json['success'] == true,
        message: json['message']?.toString(),
        docId: json['docId']?.toString(),
        docAmount: json['docAmount']?.toString(),
        customerFirmName: json['customerFirmName']?.toString(),
        customerAddress: json['customerAddress']?.toString(),
        customerCity: json['customerCity']?.toString(),
        customerPincode: json['customerPincode']?.toString(),
        status: json['status']?.toString(),
        comment: json['comment']?.toString(),
        deliveryTimestamp:
            DateTime.tryParse(json['deliveryTimestamp']?.toString() ?? ''),
        customerLocation: json['customerLocation'] is Map<String, dynamic>
            ? WebPortalDocTrackingLocation.fromJson(
                json['customerLocation'] as Map<String, dynamic>,
              )
            : null,
        driverLastKnownLocation:
            json['driverLastKnownLocation'] is Map<String, dynamic>
                ? WebPortalDocTrackingLocation.fromJson(
                    json['driverLastKnownLocation'] as Map<String, dynamic>,
                  )
                : null,
        numEnrouteCustomers: (json['numEnrouteCustomers'] as num?)?.toInt(),
        eta: (json['eta'] as num?)?.toDouble(),
      );
}
