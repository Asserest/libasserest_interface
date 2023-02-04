class AsserestException implements Exception {
  final String message;

  AsserestException([this.message = ""]);

  @override
  String toString() => "AsserestException: $message";
}