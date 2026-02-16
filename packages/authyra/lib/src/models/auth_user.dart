import 'package:equatable/equatable.dart';

/// Represents an authenticated user profile information
class AuthUser extends Equatable {
  /// Unique identifier for this account
  final String id;

  /// User's email address
  final String? email;

  /// Display name for the user
  final String? name;

  /// URL to user's profile avatar
  final String? avatarUrl;

  /// Additional metadata for the account
  ///
  /// Can store custom fields like roles, permissions, preferences, etc.
  final Map<String, dynamic> metadata;

  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
    this.metadata = const {},
  });

  /// User display name with fallback logic
  String get displayName => name ?? email ?? 'User $id';

  /// User initials for avatar fallback
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name![0].toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return 'U';
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
    String? provider,
    DateTime? createdAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'metadata': metadata,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [id, email, name, avatarUrl, metadata];

  @override
  String toString() => 'AuthUser(id: $id, email: $email';
}
