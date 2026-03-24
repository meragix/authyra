import 'package:equatable/equatable.dart';

/// Optional contextual metadata attached to an [AuthSession].
///
/// [SessionMetadata] captures device and network context at session creation
/// time. It is intentionally passive — Authyra never reads these values
/// internally; they are surfaced to consumers (e.g., audit logs, fraud
/// detection, device management UIs).
///
/// ## How to populate
///
/// Supply metadata via the [AuthCallbacks.onBeforeSessionCreate] hook:
///
/// ```dart
/// AuthCallbacks(
///   onBeforeSessionCreate: (user, providerId) async {
///     return CallbackResult.allow(data: SessionMetadata(
///       ipAddress: request.connectionInfo?.remoteAddress.address,
///       userAgent: request.headers['user-agent'],
///       deviceId: await getDeviceId(),
///     ));
///   },
/// )
/// ```
///
/// See also:
/// - [AuthSession], which holds this metadata as an optional field.
/// - [AuthCallbacks], for populating metadata before session creation.
class SessionMetadata extends Equatable {
  /// IP address of the client that initiated sign-in, if available.
  ///
  /// Useful for server-side auth flows (e.g., Shelf / Dart Frog backends).
  final String? ipAddress;

  /// HTTP `User-Agent` string of the client, if available.
  final String? userAgent;

  /// A stable device identifier (e.g., generated UUID stored on device).
  ///
  /// Enables per-device session tracking and trusted-device flows.
  final String? deviceId;

  /// ISO 3166-1 alpha-2 country code derived from IP geolocation, if available.
  ///
  /// Example: `'FR'` for France, `'US'` for United States.
  final String? country;

  const SessionMetadata({
    this.ipAddress,
    this.userAgent,
    this.deviceId,
    this.country,
  });

  /// Returns a copy of this metadata with the specified fields replaced.
  SessionMetadata copyWith({
    String? ipAddress,
    String? userAgent,
    String? deviceId,
    String? country,
  }) {
    return SessionMetadata(
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      deviceId: deviceId ?? this.deviceId,
      country: country ?? this.country,
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'deviceId': deviceId,
        'country': country,
      };

  /// Deserialises from a JSON map.
  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      deviceId: json['deviceId'] as String?,
      country: json['country'] as String?,
    );
  }

  @override
  List<Object?> get props => [ipAddress, userAgent, deviceId, country];

  @override
  String toString() =>
      'SessionMetadata(ip: $ipAddress, deviceId: $deviceId, country: $country)';
}
