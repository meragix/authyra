// ignore_for_file: deprecated_member_use_from_same_package

/// Backward-compatibility re-export.
///
/// [MultiAccountManager] has been renamed to [AccountManager] and lives in
/// `account_manager.dart`. This file is kept to avoid breaking internal
/// imports during the transition period.
///
/// **Migrate all usages to [AccountManager] and remove this file in v0.2.0.**
library;

import 'account_manager.dart';
export 'account_manager.dart';

/// Deprecated alias for [AccountManager].
///
/// Use [AccountManager] directly.
@Deprecated('Use AccountManager instead. This alias will be removed in v0.2.0.')
typedef MultiAccountManager = AccountManager;
