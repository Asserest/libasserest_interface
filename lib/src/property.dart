import 'dart:collection';

import 'package:meta/meta.dart';

@immutable
abstract class AsserestProperty {
  const AsserestProperty._();

  @protected
  String get scheme;

  String? get userInfo;

  String get host;

  int? get port;

  UnmodifiableListView<String>? get path;

  UnmodifiableMapView<String, String>? get query;

  Duration get timeout;

  bool get accessible;

  int? get tryCount;
}

extension AsserestPropertyUriGenerator on AsserestProperty {
  Uri generateUri() => Uri(
      scheme: scheme,
      userInfo: userInfo,
      host: host,
      port: port,
      pathSegments: path,
      queryParameters: query);
}
