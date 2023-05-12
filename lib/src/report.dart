import 'package:meta/meta.dart';

/// Enumerated value for indicating tester result.
enum AsserestResult {
  /// The test result is in expected.
  success,
  /// The test result is difference with expected.
  failure,
  /// Any error thrown by non-Asserest related elements.
  error
}

/// Report object for asserting [url]'s accessibility.
/// 
/// This should not be inherted or implemented to prevent
/// modification of value.
@immutable
abstract interface class AsserestReport {
  const AsserestReport._();

  /// Tested URL in [URI] object form.
  Uri get url;
  
  /// Expected the given [url] is accessible when assume no
  /// unexpected [AsserestResult.error] returned in [actual].
  bool get expected;

  /// Enumerated value of actual result after the [url] has been
  /// asserted by tester.
  AsserestResult get actual;

  /// An optional variable to counting exection duration for testing
  /// [url].
  /// 
  /// If return [Null], it means either the tester does not support
  /// counting or disabled by user.
  Duration? get executeDuration;

  /// Return an unmodifiable [Map] object for storing entire
  /// [AsserestReport] as corresponded JSON form in Dart.
  /// 
  /// [executeDuration] will be converted to [Duration.toString]
  /// if applied.
  Map<String, dynamic> toMap(); 

  /// Generate a [String] which contains all provided element in this
  /// report.
  @override
  String toString();
}