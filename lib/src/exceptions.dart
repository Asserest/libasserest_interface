class AsserestError extends Error {
  final String message;

  AsserestError([this.message = ""]);

  @override
  String toString() => "AsserestError: $message";
}

class AsserestException implements Exception {
  final String message;

  AsserestException([this.message = ""]);

  @override
  String toString() => "AsserestException: $message";
}