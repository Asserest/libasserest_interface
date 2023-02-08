import 'dart:collection';

import 'package:meta/meta.dart';

import 'exceptions.dart';

///
@immutable
abstract class AsserestProperty {
  const AsserestProperty._();

  Uri get url;

  Duration get timeout;

  bool get accessible;

  int? get tryCount;
}

class UndefinedSchemeParserException extends AsserestException {
  final String scheme;

  UndefinedSchemeParserException._(this.scheme)
      : super("The applied scheme is undefined");

  @override
  String toString() {
    StringBuffer buf = StringBuffer(super.toString())
      ..writeln("Applied scheme: $scheme");

    return buf.toString();
  }
}

abstract class PropertyParseProcessor<T extends AsserestProperty> {
  const PropertyParseProcessor();

  @protected
  String get schemeRegex;

  @protected
  T createProperty(Uri url, Duration timeout, bool accessible, int? tryCount,
      UnmodifiableMapView<String, dynamic> additionalProperty);

  @protected
  @mustCallSuper
  T parse(Map<String, dynamic> propertyMap) {
    final Uri url = Uri.parse(propertyMap["url"]);
    final Duration timeout = Duration(seconds: propertyMap["timeout"] ?? 10);
    final bool accessible = propertyMap["accessible"];
    final int? tryCount = propertyMap["try_count"];

    if (!RegExp(schemeRegex, caseSensitive: false, dotAll: false, unicode: true)
        .hasMatch(url.scheme)) {
      throw StateError(
          "URL scheme '${url.scheme}' is not handled by this processor.");
    } else if ((tryCount == null) ^ accessible) {
      throw ArgumentError.value(tryCount, "try_count",
          "Try count is required only if the URL is accessible.");
    }

    return createProperty(
        url,
        timeout,
        accessible,
        tryCount,
        UnmodifiableMapView(Map.fromEntries(propertyMap.entries.where(
            (element) => !{"url", "timeout", "accessible", "try_count"}
                .contains(element)))));
  }
}

@sealed
class AsserestPropertyParser {
  static final AsserestPropertyParser _instance = AsserestPropertyParser._();
  final Set<PropertyParseProcessor> _parseProcessors = HashSet(
      equals: (p0, p1) => p0.schemeRegex == p1.schemeRegex,
      hashCode: (processor) => processor.schemeRegex.hashCode);

  AsserestPropertyParser._();

  factory AsserestPropertyParser() => _instance;

  bool isDefined(String scheme) => _parseProcessors
      .any((element) => RegExp(element.schemeRegex).hasMatch(scheme));

  void define(PropertyParseProcessor processor,
      {bool replaceIfDefined = false}) {
    if (_parseProcessors.contains(processor) && replaceIfDefined) {
      _parseProcessors.remove(processor);
    }

    _parseProcessors.add(processor);
  }

  AsserestProperty parse(Map<String, dynamic> propertyMap) {
    return _parseProcessors
        .singleWhere((element) => RegExp(element.schemeRegex,
                caseSensitive: false, dotAll: false, unicode: true)
            .hasMatch(propertyMap["url"]))
        .parse(propertyMap);
  }

  List<AsserestProperty> parseList(List<Map<String, dynamic>> propertyMaps) =>
      List.generate(propertyMaps.length, (index) => parse(propertyMaps[index]),
          growable: false);
}
