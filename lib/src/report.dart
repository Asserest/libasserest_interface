import 'package:meta/meta.dart';

enum AsserestResult {
  success, failure, error
}

@immutable
abstract class AsserestReport {
  const AsserestReport._();

  Uri get url;
  bool get expected;
  AsserestResult get actual;
  Duration? get executeDuration;

  Map<String, dynamic> toMap(); 

  @override
  String toString();
}