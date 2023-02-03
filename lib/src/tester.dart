import 'dart:collection';
import 'dart:convert';

import 'package:async_task/async_task.dart';
import 'package:async_task/async_task_extension.dart';
import 'package:meta/meta.dart';

import 'property.dart';
import 'report.dart';

extension on AsserestResult {
  String get _readableName {
    String ogName = this.name;

    return "${ogName[0].toUpperCase()}${ogName.substring(1)}";
  }
}

@immutable
class _AsserestReport implements AsserestReport {
  @override
  final Uri url;

  @override
  final bool expected;

  @override
  final AsserestResult actual;

  @override
  final Duration? executeDuration;

  _AsserestReport(this.url, this.expected, this.actual, this.executeDuration);

  @override
  Map<String, dynamic> toMap() => UnmodifiableMapView({
        "url": "$url",
        "expected": expected,
        "actual": actual._readableName,
        "duration": executeDuration?.toString()
      });

  @override
  String toString() {
    StringBuffer buf = StringBuffer("AsserestReport")
      ..write(jsonEncode(toMap()));

    return buf.toString();
  }
}

abstract class AsserestTestPlatform<T extends AsserestProperty>
    extends AsyncTask<T, AsserestReport> {
  final T property;
  final bool _counter;

  AsserestTestPlatform(this.property, {bool counter = false}) : _counter = counter;

  @protected
  Future<AsserestResult> runTestProcess();

  @override
  @mustCallSuper
  FutureOr<AsserestReport> run() async {
    late AsserestResult result;
    final Stopwatch c = Stopwatch()..start();

    try {
      result = await runTestProcess();
    } catch (_) {
      result = AsserestResult.error;
    } finally {
      c.stop();
    }

    return _AsserestReport(property.generateUri(), property.isResolved, result, c.elapsed);
  }
}
