/// Result of a callback execution
class CallbackResult {
  final bool shouldContinue;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  const CallbackResult.allow([this.data])
      : shouldContinue = true,
        errorMessage = null;

  const CallbackResult.deny(this.errorMessage, [this.data]) : shouldContinue = false;

  bool get isAllowed => shouldContinue;
  bool get isDenied => !shouldContinue;
}
