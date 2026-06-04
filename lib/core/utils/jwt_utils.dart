import 'dart:convert';

class JwtPayload {
  JwtPayload({
    this.id,
    this.username,
    this.mobile,
    this.roles,
    this.locationHeartBeatFrequencyInSeconds,
    this.baseLocationId,
    this.baseLocationName,
    required this.iat,
    required this.exp,
  });

  final String? id;
  final String? username;
  final String? mobile;
  final String? roles;
  final int? locationHeartBeatFrequencyInSeconds;
  final String? baseLocationId;
  final String? baseLocationName;
  final int iat;
  final int exp;

  static JwtPayload? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payloadJson) as Map<String, dynamic>;
      return JwtPayload(
        id: map['id']?.toString(),
        username: map['username']?.toString(),
        mobile: map['mobile']?.toString(),
        roles: map['roles']?.toString(),
        locationHeartBeatFrequencyInSeconds:
            (map['locationHeartBeatFrequencyInSeconds'] as num?)?.toInt(),
        baseLocationId: map['baseLocationId']?.toString(),
        baseLocationName: map['baseLocationName']?.toString(),
        iat: (map['iat'] as num).toInt(),
        exp: (map['exp'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  bool get isValid => DateTime.now().millisecondsSinceEpoch < exp * 1000;
}

class JwtUtils {
  JwtUtils._();

  static bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    return JwtPayload.decode(token)?.isValid ?? false;
  }

  static String bearerToken(String token) => 'Bearer $token';
}
