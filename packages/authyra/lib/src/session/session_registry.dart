import 'package:equatable/equatable.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Immutable registry that manages multiple concurrent authenticated sessions.
///
/// [SessionRegistry] is the core data structure for multi-account support in
/// Authyra. It holds a map of `userId → AuthSession`, tracks which account is
/// currently active, and exposes a rich set of read-only accessors and
/// immutable mutation methods.
///
/// ## Immutability contract
///
/// Every mutation method (e.g., [addSession], [removeSession], [switchTo])
/// returns a **new** [SessionRegistry] instance. The original is never
/// mutated. This makes the registry safe to use as a value in `StateNotifier`,
/// `BLoC`, or any other immutable state container.
///
/// ## Multi-account flow
///
/// ```dart
/// var registry = const SessionRegistry();
///
/// // Sign in the first account
/// registry = registry.addSession(aliceSession);
///
/// // Sign in a second account (stays active)
/// registry = registry.addSession(bobSession, setAsActive: false);
///
/// // Switch to Bob
/// registry = registry.switchTo(bob.id);
///
/// // Refresh Alice's token in the background
/// registry = registry.updateSession(alice.id, refreshedAliceSession);
///
/// // Sign out the active account
/// registry = registry.removeSession(registry.activeUserId!);
/// ```
///
/// See also:
/// - [AuthSession], the per-account session stored inside this registry.
/// - [AuthUser], the identity object accessible via [allUsers].
class SessionRegistry extends Equatable {
  // Sentinel used by [copyWith] to distinguish "not provided" from explicit
  // `null` when clearing [activeUserId].
  static const Object _unset = Object();

  /// Map of `userId → AuthSession` for all registered accounts.
  ///
  /// Keys correspond to [AuthUser.id]. Iteration order is insertion order;
  /// use [allSessions] for a recency-sorted view.
  final Map<String, AuthSession> sessions;

  /// The [AuthUser.id] of the currently active account.
  ///
  /// `null` when the registry is empty or after all sessions are removed.
  /// Use [activeSession] to obtain the full session for this user.
  final String? activeUserId;

  /// UTC timestamp of the last structural mutation to this registry.
  ///
  /// Updated by every mutation method. Useful for cache invalidation or
  /// detecting staleness in persistence layers.
  final DateTime? lastUpdated;

  /// Creates a [SessionRegistry].
  ///
  /// All fields are optional; defaults to an empty registry with no active
  /// user.
  const SessionRegistry({
    this.sessions = const {},
    this.activeUserId,
    this.lastUpdated,
  });

  // ---------------------------------------------------------------------------
  // Read-only accessors
  // ---------------------------------------------------------------------------

  /// The currently active [AuthSession], or `null` if no account is active.
  AuthSession? get activeSession =>
      activeUserId != null ? sessions[activeUserId] : null;

  /// Whether the registry contains any sessions (signed-in or expired).
  bool get hasAnySession => sessions.isNotEmpty;

  /// Whether there is an active session that has **not** expired.
  bool get hasActiveSession =>
      activeSession != null && !activeSession!.isExpired;

  /// Total number of registered accounts, including expired ones.
  int get accountCount => sessions.length;

  /// Whether [userId] has a registered session.
  bool hasUser(String userId) => sessions.containsKey(userId);

  /// All registered [AuthUser] objects, sorted by most recently used first.
  List<AuthUser> get allUsers {
    final sorted = sessions.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return sorted.map((s) => s.user).toList();
  }

  /// All [AuthSession] objects, sorted by most recently used first.
  List<AuthSession> get allSessions {
    return sessions.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  // ---------------------------------------------------------------------------
  // Mutation methods (all return a new [SessionRegistry])
  // ---------------------------------------------------------------------------

  /// Adds or replaces the session for [session.user.id].
  ///
  /// When [setAsActive] is `true` (the default), the new session becomes the
  /// active account. Set it to `false` when signing in a background account
  /// without switching away from the current one.
  ///
  /// ```dart
  /// // Sign in and activate
  /// registry = registry.addSession(aliceSession);
  ///
  /// // Sign in silently in the background
  /// registry = registry.addSession(bobSession, setAsActive: false);
  /// ```
  SessionRegistry addSession(AuthSession session, {bool setAsActive = true}) {
    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[session.user.id] = session;

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: setAsActive ? session.user.id : activeUserId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Removes the session identified by [userId].
  ///
  /// When the removed account was the active one, the registry automatically
  /// elects the most recently used remaining account as the new active user.
  /// If no accounts remain, [activeUserId] becomes `null`.
  ///
  /// Returns `this` unchanged when [userId] is not found.
  SessionRegistry removeSession(String userId) {
    if (!sessions.containsKey(userId)) return this;

    final newSessions = Map<String, AuthSession>.from(sessions)..remove(userId);

    String? newActiveUserId = activeUserId;
    if (activeUserId == userId) {
      if (newSessions.isNotEmpty) {
        // Elect the most recently used remaining account.
        final sorted = newSessions.values.toList()
          ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        newActiveUserId = sorted.first.user.id;
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

  /// Switches the active account to [userId] and marks it as used.
  ///
  /// Updates [AuthSession.lastUsedAt] for [userId] so that recency-based
  /// ordering in [allSessions] reflects the switch.
  ///
  /// Returns `this` unchanged when [userId] is not found.
  SessionRegistry switchTo(String userId) {
    if (!sessions.containsKey(userId)) return this;

    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[userId] = sessions[userId]!.markAsUsed();

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: userId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Replaces the session for [userId] with an updated [session].
  ///
  /// Typically used after a token refresh to apply new tokens without
  /// changing the active account or other sessions.
  ///
  /// Returns `this` unchanged when [userId] is not found.
  ///
  /// ```dart
  /// final renewed = session.refreshed(
  ///   newAccessToken: response.accessToken,
  ///   newExpiresAt: response.expiresAt,
  /// );
  /// registry = registry.updateSession(session.user.id, renewed);
  /// ```
  SessionRegistry updateSession(String userId, AuthSession session) {
    if (!sessions.containsKey(userId)) return this;

    final newSessions = Map<String, AuthSession>.from(sessions);
    newSessions[userId] = session;

    return SessionRegistry(
      sessions: newSessions,
      activeUserId: activeUserId,
      lastUpdated: DateTime.now(),
    );
  }

  /// Removes all expired sessions and elects a new active account if needed.
  ///
  /// When the active session was expired and removed, the most recently used
  /// non-expired session is elected as active. If none remain, [activeUserId]
  /// becomes `null`.
  ///
  /// Call this periodically (e.g., on app resume) to keep the registry clean.
  SessionRegistry removeExpiredSessions() {
    final newSessions = Map<String, AuthSession>.from(sessions)
      ..removeWhere((_, session) => session.isExpired);

    String? newActiveUserId = activeUserId;
    if (activeUserId != null && !newSessions.containsKey(activeUserId)) {
      if (newSessions.isNotEmpty) {
        // Elect the most recently used non-expired account.
        final sorted = newSessions.values.toList()
          ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        newActiveUserId = sorted.first.user.id;
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

  /// Removes all sessions and clears the active account.
  ///
  /// Equivalent to a full sign-out of all accounts.
  SessionRegistry clearAll() {
    return SessionRegistry(
      sessions: const {},
      activeUserId: null,
      lastUpdated: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  /// Returns a copy of this registry with the specified fields replaced.
  ///
  /// To explicitly clear [activeUserId] to `null`, pass
  /// `activeUserId: null`:
  ///
  /// ```dart
  /// // Retain current activeUserId
  /// registry.copyWith(sessions: newSessions);
  ///
  /// // Explicitly clear activeUserId
  /// registry.copyWith(activeUserId: null);
  /// ```
  SessionRegistry copyWith({
    Map<String, AuthSession>? sessions,
    Object? activeUserId = _unset,
    DateTime? lastUpdated,
  }) {
    return SessionRegistry(
      sessions: sessions ?? this.sessions,
      activeUserId: identical(activeUserId, _unset)
          ? this.activeUserId
          : activeUserId as String?,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises the registry to a JSON-compatible map.
  ///
  /// Suitable for persisting the full multi-account state. Ensure that the
  /// storage backend is encrypted; this map contains raw access tokens.
  Map<String, dynamic> toJson() => {
        'sessions': sessions.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'activeUserId': activeUserId,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  /// Deserialises a [SessionRegistry] from a JSON map.
  ///
  /// [lastUpdated] falls back to [DateTime.now] when absent, which is safe for
  /// registries migrated from older storage formats.
  factory SessionRegistry.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as Map<String, dynamic>? ?? {};
    final sessions = sessionsJson.map(
      (key, value) =>
          MapEntry(key, AuthSession.fromJson(value as Map<String, dynamic>)),
    );

    return SessionRegistry(
      sessions: sessions,
      activeUserId: json['activeUserId'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Equatable / Object
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [sessions, activeUserId, lastUpdated];

  @override
  String toString() =>
      'SessionRegistry(accounts: $accountCount, active: $activeUserId)';
}
