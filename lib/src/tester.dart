import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:async_task/async_task.dart';
import 'package:meta/meta.dart';

import 'property.dart';
import 'report.dart';

extension on AsserestResult {
  /// Get readable [name] by captalize first character of [String]
  String get _readableName {
    String ogName = this.name;

    return "${ogName[0].toUpperCase()}${ogName.substring(1)}";
  }
}

/// Implemented [AsserestReport] object.
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

/// A platform for executing assertion from given [AsserestProperty]'s subclass [T].
///
/// This is [AsyncTask] based class with integrated stopwatch system for marking
/// execution duration.
abstract class AsserestTestPlatform<T extends AsserestProperty>
    extends AsyncTask<T, AsserestReport> {
  /// [AsserestProperty] for running this test.
  final T property;
  final bool _counter;

  /// Create new test platform for asserting [property].
  ///
  /// If [counter] enabled, [AsserestReport.executeDuration] will be provided
  /// when assertion finished.
  AsserestTestPlatform(this.property, {bool counter = false})
      : _counter = counter;

  /// The process for asserting and return [AsserestResult] to determine
  /// accessibility of [AsserestProperty.url].
  @protected
  Future<AsserestResult> runTestProcess();

  /// The entire assertion task will be processed once [run] has been
  /// invoked.
  ///
  /// This method **MUST NOT** be overridden and intent for callback only.
  /// For implementing assertion processor, please override [runTestProcess]
  /// instead.
  @override
  @mustCallSuper
  Future<AsserestReport> run() async {
    late AsserestResult result;
    final Stopwatch c = Stopwatch();
    if (_counter) {
      c.start();
    }

    try {
      result = await runTestProcess();
    } catch (_) {
      result = AsserestResult.error;
    } finally {
      if (c.isRunning) {
        c.stop();
      }
    }

    return _AsserestReport(
        property.url, property.accessible, result, _counter ? c.elapsed : null);
  }
}

/// Alias definition of constructing [AsserestTestPlatform] from given [property].
typedef AsserestTestPlatformBuilder = AsserestTestPlatform Function(
    AsserestProperty property);

/// A handler for assigning [AsserestTestPlatform] from [AsserestProperty].
@sealed
class AsserestTestAssigner {
  static final AsserestTestAssigner _instance = AsserestTestAssigner._();

  final Map<Type, AsserestTestPlatformBuilder> _platformBuilders = {};

  AsserestTestAssigner._();

  /// Return current instance of [AsserestTestAssigner].
  factory AsserestTestAssigner() => _instance;

  /// Bind [platformBuilder] with corresponsed [propertyType].
  /// 
  /// ### Warning
  /// 
  /// There is no type guard system for verifying [propertyType] and parameter
  /// of [platformBuilder]. Thus, it cannot be undone after [assign] is called.
  /// 
  /// If the incorrect [propertyType] assigned, the only solution is [reset]
  /// and repeat [assign] process.
  void assign(Type propertyType, AsserestTestPlatformBuilder platformBuilder,
      {bool replaceIfAssigned = false}) {
    if (replaceIfAssigned || !isAssigned(propertyType)) {
      _platformBuilders[propertyType] = platformBuilder;
    }
  }

  void reset() {
    _platformBuilders.clear();
  }

  bool isAssigned(Type propertyType) =>
      _platformBuilders.containsKey(propertyType);

  AsserestTestPlatform _buildTestPlatform(AsserestProperty property) =>
      _platformBuilders[property.runtimeType]!(property);
}

class _AsserestParallelTestPlatformStreamSubscription
    implements StreamSubscription<AsserestReport> {
  final StreamSubscription<AsserestReport> _base;
  final AsyncExecutor _executor;

  _AsserestParallelTestPlatformStreamSubscription(this._base, this._executor) {
    this.onDone(null);
    this.onError(null);
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _base.asFuture<E>(futureValue);
  }

  @override
  Future<void> cancel() async {
    await _base.cancel();
    await _executor.close();
  }

  @override
  bool get isPaused => _base.isPaused;

  @override
  void onData(void Function(AsserestReport data)? handleData) {
    _base.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _base.onDone(() async {
      await _executor.close();
      (handleDone ?? () {})();
    });
  }

  @override
  void onError(Function? handleError) {
    _base.onError((err, stackTrace) async {
      await _executor.close();
      if (handleError != null) {
        handleError(err, stackTrace);
      } else {
        throw err;
      }
    });
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _base.pause(resumeSignal);
  }

  @override
  void resume() {
    _base.resume();
  }
}

/// A [Set] which allows [AsyncTask] to identify all provided [AsserestTestPlatform]
/// subclasses.
class _AsserestParallelTestTypeSet extends SetBase<AsserestTestPlatform> {
  final HashMap<Type, AsserestTestPlatform> _typeMap = HashMap();

  @override
  bool add(AsserestTestPlatform<AsserestProperty> value) {
    final int expLen = length + 1;
    _typeMap.putIfAbsent(value.runtimeType, () => value);
    return _typeMap.length == expLen;
  }

  @override
  bool contains(Object? element) {
    return _typeMap.containsValue(element);
  }

  @override
  Iterator<AsserestTestPlatform<AsserestProperty>> get iterator =>
      _typeMap.values.iterator;

  @override
  int get length => _typeMap.length;

  @override
  AsserestTestPlatform<AsserestProperty>? lookup(Object? element) {
    return _typeMap[element];
  }

  @override
  bool remove(Object? value) {
    throw UnsupportedError("Removing added type assignment is forbidden.");
  }

  @override
  Set<AsserestTestPlatform<AsserestProperty>> toSet() {
    return _typeMap.values.toSet();
  }

  @override
  List<AsserestTestPlatform<AsserestProperty>> toList({bool growable = false}) {
    return _typeMap.values.toList(growable: growable);
  }
}

typedef void AsyncExecutorLogger(String type, dynamic message,
    [dynamic error, dynamic stackTrace]);

@sealed
class AsserestParallelTestPlatform extends IterableBase<AsserestTestPlatform> {
  /// A [Map] with [AsserestProperty.hashCode] as reference.
  final Map<int, AsserestTestPlatform> _platforms = {};
  final _AsserestParallelTestTypeSet _typeSet = _AsserestParallelTestTypeSet();

  final int threads;

  AsserestParallelTestPlatform({this.threads = 1});

  @override
  Iterator<AsserestTestPlatform<AsserestProperty>> get iterator =>
      _platforms.values.iterator;

  int get length => _platforms.length;

  void apply(AsserestProperty property) {
    AsserestTestPlatform platform =
        AsserestTestAssigner()._buildTestPlatform(property);
    _platforms[property.hashCode] = platform;
    _typeSet.add(platform);
  }

  void appplyAll(Iterable<AsserestProperty> properites) {
    properites.forEach(apply);
  }

  StreamSubscription<AsserestReport> runAll(
      {String? name,
      AsyncExecutorLogger? logger,
      void Function(AsserestReport data)? onData,
      void Function()? onDone,
      Function? onError,
      bool? cancelOnError}) {
    final AsyncExecutor executor = AsyncExecutor(
        name: name ?? "Asserest parallel test - ${DateTime.now()}",
        logger: logger,
        sequential: false,
        parallelism: threads,
        taskTypeRegister: _typeSet.toList);

    Stream<AsserestReport> reportStream =
        Stream.fromFutures(executor.executeAll(_platforms.values));
    return _AsserestParallelTestPlatformStreamSubscription(
        reportStream.listen(onData,
            onDone: onDone, onError: onError, cancelOnError: cancelOnError),
        executor);
  }
}
