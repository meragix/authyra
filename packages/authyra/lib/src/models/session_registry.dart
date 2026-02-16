import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:equatable/equatable.dart';

/// Registry that manages multiple authenticated sessions
class SessionRegistry extends Equatable {
  /// Map of userId -> AuthSession
  final Map<String, AuthSession> sessions;

  /// Currently active user ID
  final String? activeUserId;

  /// When the registry was last updated
  final DateTime? lastUpdated;

  const SessionRegistry({
    this.sessions = const {},
    this.activeUserId,
    this.lastUpdated,
  });

  /// Get the active session
  AuthSession? get activeSession => activeUserId != null ? sessions[activeUserId] : null;

  /// Get all users (sorted by last used)
  List<AuthUser> get allUsers {
    final users = sessions.values.map((s) => s.user).toList();
    users.sort((a, b) {
      final sessionA = sessions[a.id]!;
      final sessionB = sessions[b.id]!;
      return sessionB.lastUsedAt.compareTo(sessionA.lastUsedAt);
    });
    return users;
  }

  /// Get all sessions as a list (sorted by last used)
  List<AuthSession> get allSessions {
    final sessionList = sessions.values.toList();
    sessionList.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return sessionList;
  }

  /// Check if a user is registered
  bool hasUser(String userId) => sessions.containsKey(userId);

  /// Check if any user is authenticated
  bool get hasAnySession => sessions.isNotEmpty;

  /// Check if there's an active valid session
  bool get hasActiveSession => activeSession != null && !activeSession!.isExpired;

  /// Count of registered accounts
  int get accountCount => sessions.length;

  /// Add or update a session
  SessionRegistry addSession(AuthSession session, {bool setAsActive = true}) {
    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[session.user.id] = session;

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: setAsActive ? session.user.id : activeUserId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Remove a session
  SessionRegistry removeSession(String userId) {
    if (!sessions.containsKey(userId)) {
      return this;
    }

    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions.remove(userId);

    // Determine new active user
    String? newActiveUserId = activeUserId;
    if (activeUserId == userId) {
      // Pick the most recently used account
      if (newSessions.isNotEmpty) {
        final sortedSessions = newSessions.values.toList()..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        newActiveUserId = sortedSessions.first.user.id;
      } else {
        newActiveUserId = null;
      }
    }

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: newActiveUserId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Switch to a different account
  SessionRegistry switchTo(String userId) {
    if (!sessions.containsKey(userId)) {
      return this;
    }

    // Mark the session as used
    final updatedSession = sessions[userId]!.markAsUsed();
    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[userId] = updatedSession;

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: userId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Update a specific session (e.g., after token refresh)
  SessionRegistry updateSession(String userId, AuthSession session) {
    if (!sessions.containsKey(userId)) {
      return this;
    }

    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[userId] = session;

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: activeUserId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Clear all sessions
  SessionRegistry clearAll() {
    return SessionRegistry(
      sessions: {},
      activeUserId: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Remove expired sessions
  SessionRegistry removeExpiredSessions() {
    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions.removeWhere((_, session) => session.isExpired);

    String? newActiveUserId = activeUserId;
    if (activeUserId != null && !newSessions.containsKey(activeUserId)) {
      newActiveUserId = newSessions.isNotEmpty ? newSessions.keys.first : null;
    }

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: newActiveUserId,
      lastUpdated: DateTime.now(),
    );
  }

  SessionRegistry copyWith({
    Map<String, AuthSession>? sessions,
    String? activeUserId,
    DateTime? lastUpdated,
  }) {
    return SessionRegistry(
      sessions: sessions ?? this.sessions,
      activeUserId: activeUserId ?? this.activeUserId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessions': sessions.map((key, value) => MapEntry(key, value.toJson())),
        'activeUserId': activeUserId,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory SessionRegistry.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as Map<String, dynamic>? ?? {};
    final sessions = sessionsJson.map(
      (key, value) => MapEntry(key, AuthSession.fromJson(value as Map<String, dynamic>)),
    );

    return SessionRegistry(
      sessions: sessions,
      activeUserId: json['activeUserId'] as String?,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated'] as String) : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [sessions, activeUserId, lastUpdated];

  @override
  String toString() => 'SessionRegistry(accounts: $accountCount, active: $activeUserId)';
}
