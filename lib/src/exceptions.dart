import 'report.dart' show AsserestResult;

/// A generic interface for indicating Asserest related
/// [Error] and [Exception].
abstract class AsserestThrowable {
  const AsserestThrowable._();

  /// An message of this throwable object.
  String get message;

  /// A [String] will be used for describe throwable information
  /// in terminal.
  /// 
  /// The content should be as detail as possible.
  @override
  String toString();
}

/// An [Error] based throwable for any execution error in Asserest.
class AsserestError extends Error implements AsserestThrowable {
  final String message;

  AsserestError([this.message = ""]);

  @override
  String toString() => "AsserestError: $message";
}

/// An [Exception] based throwable for unexpected operation by user.
class AsserestException implements Exception, AsserestThrowable {
  final String message;

  AsserestException([this.message = ""]);

  @override
  String toString() => "AsserestException: $message";
}