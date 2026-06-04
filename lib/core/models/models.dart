class ApiResponse {
  ApiResponse({this.message, this.error, this.statusCode});

  final String? message;
  final String? error;
  final int? statusCode;

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
        message: json['message']?.toString(),
        error: json['error']?.toString(),
        statusCode: (json['statusCode'] as num?)?.toInt(),
      );
}

class LoginRequest {
  LoginRequest({required this.mobile});
  final String mobile;

  Map<String, dynamic> toJson() => {'mobile': mobile};
}

class OtpRequestBody {
  OtpRequestBody({required this.mobile, required this.otp});
  final String mobile;
  final String otp;

  Map<String, dynamic> toJson() => {'mobile': mobile, 'otp': otp};
}

class OtpVerificationResponse {
  OtpVerificationResponse({this.accessToken});
  final String? accessToken;

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) =>
      OtpVerificationResponse(accessToken: json['access_token']?.toString());
}

class LocationData {
  LocationData({required this.latitude, required this.longitude});
  final String latitude;
  final String longitude;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class ScanDocSuccessResponse {
  ScanDocSuccessResponse({
    required this.success,
    required this.message,
    required this.docId,
  });

  final bool success;
  final String message;
  final String docId;

  factory ScanDocSuccessResponse.fromJson(Map<String, dynamic> json) =>
      ScanDocSuccessResponse(
        success: json['success'] == true,
        message: json['message']?.toString() ?? '',
        docId: json['docId']?.toString() ?? '',
      );
}

class UserSummaryList {
  UserSummaryList({
    this.scannedByUserId,
    this.scannedByName,
    this.scannedFromLocation,
    this.count,
    this.docIdList,
    this.isSelected = false,
  });

  final String? scannedByUserId;
  final String? scannedByName;
  final String? scannedFromLocation;
  final int? count;
  final List<String>? docIdList;
  bool isSelected;

  factory UserSummaryList.fromJson(Map<String, dynamic> json) =>
      UserSummaryList(
        scannedByUserId: json['scannedByUserId']?.toString(),
        scannedByName: json['scannedByName']?.toString(),
        scannedFromLocation: json['scannedFromLocation']?.toString(),
        count: (json['count'] as num?)?.toInt(),
        docIdList: (json['docIdList'] as List?)
            ?.map((e) => e.toString())
            .toList(),
      );
}

class RouteSummaryList {
  RouteSummaryList({this.route, this.userSummaryList});

  final String? route;
  final List<UserSummaryList>? userSummaryList;

  factory RouteSummaryList.fromJson(Map<String, dynamic> json) =>
      RouteSummaryList(
        route: json['route']?.toString(),
        userSummaryList: (json['userSummaryList'] as List?)
            ?.map((e) => UserSummaryList.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DispatchQueueListData {
  DispatchQueueListData({this.routeSummaryList});

  final List<RouteSummaryList>? routeSummaryList;

  factory DispatchQueueListData.fromJson(Map<String, dynamic> json) =>
      DispatchQueueListData(
        routeSummaryList: (json['routeSummaryList'] as List?)
            ?.map((e) => RouteSummaryList.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DispatchQueueResponse {
  DispatchQueueResponse({
    this.success,
    this.message,
    this.dispatchQueueList,
    this.totalDocs,
  });

  final bool? success;
  final String? message;
  final DispatchQueueListData? dispatchQueueList;
  final int? totalDocs;

  factory DispatchQueueResponse.fromJson(Map<String, dynamic> json) =>
      DispatchQueueResponse(
        success: json['success'] as bool?,
        message: json['message']?.toString(),
        dispatchQueueList: json['dispatchQueueList'] != null
            ? DispatchQueueListData.fromJson(
                json['dispatchQueueList'] as Map<String, dynamic>,
              )
            : null,
        totalDocs: (json['totalDocs'] as num?)?.toInt(),
      );
}

class Driver {
  Driver({
    this.userId,
    this.driverName,
    this.vehicleNumber,
    this.baseLocationName,
    this.sameLocation,
    this.self,
  });

  final String? userId;
  final String? driverName;
  final String? vehicleNumber;
  final String? baseLocationName;
  final bool? sameLocation;
  final bool? self;

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        userId: json['userId']?.toString(),
        driverName: json['driverName']?.toString(),
        vehicleNumber: json['vehicleNumber']?.toString(),
        baseLocationName: json['baseLocationName']?.toString(),
        sameLocation: json['sameLocation'] as bool?,
        self: json['self'] as bool?,
      );
}

class DriverListResponse {
  DriverListResponse({this.success, this.message, this.drivers});

  final bool? success;
  final String? message;
  final List<Driver>? drivers;

  factory DriverListResponse.fromJson(Map<String, dynamic> json) =>
      DriverListResponse(
        success: json['success'] as bool?,
        message: json['message']?.toString(),
        drivers: (json['drivers'] as List?)
            ?.map((e) => Driver.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ScheduleNewTripRequest {
  ScheduleNewTripRequest({
    required this.route,
    required this.userIds,
    required this.driverId,
    required this.vehicleNbr,
  });

  final String route;
  final List<String> userIds;
  final String driverId;
  final String vehicleNbr;

  Map<String, dynamic> toJson() => {
        'route': route,
        'userIds': userIds,
        'driverId': driverId,
        'vehicleNbr': vehicleNbr,
      };
}

class ScheduleNewTripResponse {
  ScheduleNewTripResponse({
    this.success,
    this.message,
    this.statusCode,
    this.tripId,
    this.documentsLoaded,
    this.route,
    this.driverId,
    this.vehicleNumber,
  });

  final bool? success;
  final String? message;
  final int? statusCode;
  final String? tripId;
  final int? documentsLoaded;
  final String? route;
  final String? driverId;
  final String? vehicleNumber;

  factory ScheduleNewTripResponse.fromJson(Map<String, dynamic> json) =>
      ScheduleNewTripResponse(
        success: json['success'] as bool?,
        message: json['message']?.toString(),
        statusCode: (json['statusCode'] as num?)?.toInt(),
        tripId: json['tripId']?.toString(),
        documentsLoaded: (json['documentsLoaded'] as num?)?.toInt(),
        route: json['route']?.toString(),
        driverId: json['driverId']?.toString(),
        vehicleNumber: json['vehicleNumber']?.toString(),
      );
}

class ScheduledTrip {
  ScheduledTrip({
    this.tripId,
    this.createdBy,
    this.createdById,
    this.driverName,
    this.driverId,
    this.vehicleNumber,
    this.status,
    this.route,
    this.createdAt,
    this.startedAt,
    this.lastUpdatedAt,
    this.creatorLocation,
    this.driverLocation,
    this.driverLastKnownLatitude,
    this.driverLastKnownLongitude,
    this.driverLastLocationUpdateTime,
    this.pendingDirectDeliveries,
    this.totalDirectDeliveries,
    this.deliveryCountStatusMsg,
    this.pendingLotDropOffs,
    this.dropOffCountStatusMsg,
  });

  final int? tripId;
  final String? createdBy;
  final String? createdById;
  final String? driverName;
  final String? driverId;
  final String? vehicleNumber;
  final String? status;
  final String? route;
  final String? createdAt;
  final String? startedAt;
  final String? lastUpdatedAt;
  final String? creatorLocation;
  final String? driverLocation;
  final String? driverLastKnownLatitude;
  final String? driverLastKnownLongitude;
  final String? driverLastLocationUpdateTime;
  final int? pendingDirectDeliveries;
  final int? totalDirectDeliveries;
  final String? deliveryCountStatusMsg;
  final int? pendingLotDropOffs;
  final String? dropOffCountStatusMsg;

  factory ScheduledTrip.fromJson(Map<String, dynamic> json) => ScheduledTrip(
        tripId: (json['tripId'] as num?)?.toInt(),
        createdBy: json['createdBy']?.toString(),
        createdById: json['createdById']?.toString(),
        driverName: json['driverName']?.toString(),
        driverId: json['driverId']?.toString(),
        vehicleNumber: json['vehicleNumber']?.toString(),
        status: json['status']?.toString(),
        route: json['route']?.toString(),
        createdAt: json['createdAt']?.toString(),
        startedAt: json['startedAt']?.toString(),
        lastUpdatedAt: json['lastUpdatedAt']?.toString(),
        creatorLocation: json['creatorLocation']?.toString(),
        driverLocation: json['driverLocation']?.toString(),
        driverLastKnownLatitude: json['driverLastKnownLatitude']?.toString(),
        driverLastKnownLongitude: json['driverLastKnownLongitude']?.toString(),
        driverLastLocationUpdateTime:
            json['driverLastLocationUpdateTime']?.toString(),
        pendingDirectDeliveries:
            (json['pendingDirectDeliveries'] as num?)?.toInt(),
        totalDirectDeliveries:
            (json['totalDirectDeliveries'] as num?)?.toInt(),
        deliveryCountStatusMsg: json['deliveryCountStatusMsg']?.toString(),
        pendingLotDropOffs: (json['pendingLotDropOffs'] as num?)?.toInt(),
        dropOffCountStatusMsg: json['dropOffCountStatusMsg']?.toString(),
      );
}

class ScheduledTripsResponse {
  ScheduledTripsResponse({
    this.success,
    this.message,
    this.trips,
    this.totalTrips,
    this.totalDocs,
    this.statusCode,
  });

  final bool? success;
  final String? message;
  final List<ScheduledTrip>? trips;
  final int? totalTrips;
  final int? totalDocs;
  final int? statusCode;

  factory ScheduledTripsResponse.fromJson(Map<String, dynamic> json) =>
      ScheduledTripsResponse(
        success: json['success'] as bool?,
        message: json['message']?.toString(),
        trips: (json['trips'] as List?)
            ?.map((e) => ScheduledTrip.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalTrips: (json['totalTrips'] as num?)?.toInt(),
        totalDocs: (json['totalDocs'] as num?)?.toInt(),
        statusCode: (json['statusCode'] as num?)?.toInt(),
      );
}

class Doc {
  Doc({
    this.id,
    this.status,
    this.lastScannedBy,
    this.originWarehouse,
    this.tripId,
    this.docDate,
    this.docAmount,
    this.route,
    this.lot,
    this.comment,
    this.customerId,
    this.transitHubLatitude,
    this.transitHubLongitude,
    this.createdAt,
    this.lastUpdatedAt,
    this.customerFirmName,
    this.customerAddress,
    this.customerCity,
    this.customerPincode,
    this.customerPhone,
    this.customerGeoLatitude,
    this.customerGeoLongitude,
  });

  final String? id;
  final String? status;
  final String? lastScannedBy;
  final String? originWarehouse;
  final String? tripId;
  final String? docDate;
  final String? docAmount;
  final String? route;
  final String? lot;
  final String? comment;
  final String? customerId;
  final String? transitHubLatitude;
  final String? transitHubLongitude;
  final String? createdAt;
  final String? lastUpdatedAt;
  final String? customerFirmName;
  final String? customerAddress;
  final String? customerCity;
  final String? customerPincode;
  final String? customerPhone;
  final String? customerGeoLatitude;
  final String? customerGeoLongitude;

  factory Doc.fromJson(Map<String, dynamic> json) => Doc(
        id: json['id']?.toString(),
        status: json['status']?.toString(),
        lastScannedBy: json['lastScannedBy']?.toString(),
        originWarehouse: json['originWarehouse']?.toString(),
        tripId: json['tripId']?.toString(),
        docDate: json['docDate']?.toString(),
        docAmount: json['docAmount']?.toString(),
        route: json['route']?.toString(),
        lot: json['lot']?.toString(),
        comment: json['comment']?.toString(),
        customerId: json['customerId']?.toString(),
        transitHubLatitude: json['transitHubLatitude']?.toString(),
        transitHubLongitude: json['transitHubLongitude']?.toString(),
        createdAt: json['createdAt']?.toString(),
        lastUpdatedAt: json['lastUpdatedAt']?.toString(),
        customerFirmName: json['customerFirmName']?.toString(),
        customerAddress: json['customerAddress']?.toString(),
        customerCity: json['customerCity']?.toString(),
        customerPincode: json['customerPincode']?.toString(),
        customerPhone: json['customerPhone']?.toString(),
        customerGeoLatitude: json['customerGeoLatitude']?.toString(),
        customerGeoLongitude: json['customerGeoLongitude']?.toString(),
      );
}

class DocGroup {
  DocGroup({
    this.heading,
    this.droppable = false,
    this.dropOffCompleted = false,
    this.showDropOffButton = false,
    this.expandGroupByDefault = false,
    this.docs,
  });

  final String? heading;
  final bool droppable;
  final bool dropOffCompleted;
  final bool showDropOffButton;
  final bool expandGroupByDefault;
  final List<Doc>? docs;

  factory DocGroup.fromJson(Map<String, dynamic> json) => DocGroup(
        heading: json['heading']?.toString(),
        droppable: json['droppable'] == true,
        dropOffCompleted: json['dropOffCompleted'] == true,
        showDropOffButton: json['showDropOffButton'] == true,
        expandGroupByDefault: json['expandGroupByDefault'] == true,
        docs: (json['docs'] as List?)
            ?.map((e) => Doc.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SingleTripDetailsResponse {
  SingleTripDetailsResponse({
    this.tripId,
    this.driverName,
    this.driverId,
    this.vehicleNumber,
    this.status,
    this.route,
    this.createdAt,
    this.startedAt,
    this.pendingDirectDeliveries,
    this.totalDirectDeliveries,
    this.deliveryCountStatusMsg,
    this.pendingLotDropOffs,
    this.dropOffCountStatusMsg,
    this.docGroups,
  });

  final int? tripId;
  final String? driverName;
  final String? driverId;
  final String? vehicleNumber;
  final String? status;
  final String? route;
  final String? createdAt;
  final String? startedAt;
  final int? pendingDirectDeliveries;
  final int? totalDirectDeliveries;
  final String? deliveryCountStatusMsg;
  final int? pendingLotDropOffs;
  final String? dropOffCountStatusMsg;
  final List<DocGroup>? docGroups;

  factory SingleTripDetailsResponse.fromJson(Map<String, dynamic> json) =>
      SingleTripDetailsResponse(
        tripId: (json['tripId'] as num?)?.toInt(),
        driverName: json['driverName']?.toString(),
        driverId: json['driverId']?.toString(),
        vehicleNumber: json['vehicleNumber']?.toString(),
        status: json['status']?.toString(),
        route: json['route']?.toString(),
        createdAt: json['createdAt']?.toString(),
        startedAt: json['startedAt']?.toString(),
        pendingDirectDeliveries:
            (json['pendingDirectDeliveries'] as num?)?.toInt(),
        totalDirectDeliveries:
            (json['totalDirectDeliveries'] as num?)?.toInt(),
        deliveryCountStatusMsg: json['deliveryCountStatusMsg']?.toString(),
        pendingLotDropOffs: (json['pendingLotDropOffs'] as num?)?.toInt(),
        dropOffCountStatusMsg: json['dropOffCountStatusMsg']?.toString(),
        docGroups: (json['docGroups'] as List?)
            ?.map((e) => DocGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MarkAsDeliveredRequest {
  MarkAsDeliveredRequest({
    this.signature,
    this.deliveryComment,
    this.deliveryLatitude,
    this.deliveryLongitude,
  });

  final String? signature;
  final String? deliveryComment;
  final String? deliveryLatitude;
  final String? deliveryLongitude;

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'deliveryComment': deliveryComment,
        'deliveryLatitude': deliveryLatitude,
        'deliveryLongitude': deliveryLongitude,
      };
}

class MarkAsUnDeliveredRequest {
  MarkAsUnDeliveredRequest({this.failureComment});
  final String? failureComment;

  Map<String, dynamic> toJson() => {'failureComment': failureComment};
}

class RecentSignatureResponse {
  RecentSignatureResponse({this.success, this.signature, this.message});

  final bool? success;
  final String? signature;
  final String? message;

  factory RecentSignatureResponse.fromJson(Map<String, dynamic> json) =>
      RecentSignatureResponse(
        success: json['success'] as bool?,
        signature: json['signature']?.toString(),
        message: json['message']?.toString(),
      );
}
