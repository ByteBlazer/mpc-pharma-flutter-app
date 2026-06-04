class AppConstants {
  AppConstants._();

  static const networkLossMessage =
      'Network connection lost. Please check your internet.';

  static const tripStatusScheduled = 'SCHEDULED';
  static const tripStatusStarted = 'STARTED';

  static const docStatusOnTrip = 'ON_TRIP';
  static const docStatusDelivered = 'DELIVERED';
  static const docStatusUndelivered = 'UNDELIVERED';
}

enum UserType {
  webAccess('web-access'),
  appScanner('app-scanner'),
  appTripCreator('app-trip-creator'),
  appAdmin('app-admin'),
  appTripDriver('app-trip-driver');

  const UserType(this.apiValue);
  final String apiValue;

  static UserType? fromApiValue(String value) {
    for (final type in UserType.values) {
      if (type.apiValue == value.toLowerCase()) return type;
    }
    return null;
  }
}

enum HomeTab {
  scan,
  queue,
  scheduledTrips,
  myTrips,
}

extension HomeTabRoles on HomeTab {
  Set<UserType> get visibleFor => switch (this) {
        HomeTab.scan => {
            UserType.appAdmin,
            UserType.appTripCreator,
            UserType.appScanner,
          },
        HomeTab.queue => {UserType.appAdmin, UserType.appTripCreator},
        HomeTab.scheduledTrips => {
            UserType.appAdmin,
            UserType.appTripCreator,
          },
        HomeTab.myTrips => {UserType.appAdmin, UserType.appTripDriver},
      };

  String get title => switch (this) {
        HomeTab.scan => 'Scan',
        HomeTab.queue => 'Queue',
        HomeTab.scheduledTrips => 'Trips',
        HomeTab.myTrips => 'My Trips',
      };
}
