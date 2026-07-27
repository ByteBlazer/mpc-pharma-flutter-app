class LoginRequest {
  const LoginRequest({required this.mobile});

  final String mobile;

  Map<String, dynamic> toJson() => {'mobile': mobile};
}

class OtpRequestBody {
  const OtpRequestBody({required this.mobile, required this.otp});

  final String mobile;
  final String otp;

  Map<String, dynamic> toJson() => {'mobile': mobile, 'otp': otp};
}

class OtpVerificationResponse {
  const OtpVerificationResponse({this.accessToken});

  factory OtpVerificationResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponse(
      accessToken:
          (json['access_token'] ?? json['accessToken'] ?? json['token'])
              as String?,
    );
  }

  final String? accessToken;
}
