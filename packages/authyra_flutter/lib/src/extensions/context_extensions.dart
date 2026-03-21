import 'package:authyra/authyra.dart';
import 'package:authyra_flutter/src/ui/widgets/authyra_scope.dart';
import 'package:flutter/widgets.dart';

extension AuthyraContextExtensions on BuildContext {
  Authyra get auth => AuthyraScope.of(this);
  
  Future<AuthSession?> get activeSession => auth.getSession();

  bool get isAuthenticated => auth.isAuthenticated;
}

