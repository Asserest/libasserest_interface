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
final class _AsserestReport implements AsserestReport {
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
abstract base class AsserestTestPlatform<T extends AsserestProperty>
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
final class AsserestTestAssigner {
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

  /// Flush all [assign]ed [AsserestTestPlatformBuilder].
  void reset() {
    _platformBuilders.clear();
  }

  /// Check the given [AsserestProperty]'s subclass [Type] is assigned the
  /// builder already.
  bool isAssigned(Type propertyType) =>
      _platformBuilders.containsKey(propertyType);

  /// Generate [AsserestTestPlatform] from given property.
  ///
  /// If the given [property] type does not assigned the corresponsed
  /// [AsserestTestPlatformBuilder], [TypeError] will be thrown.
  AsserestTestPlatform buildTestPlatform(AsserestProperty property) =>
      _platformBuilders[property.runtimeType]!(property);
}

/// A [Set] which allows [AsyncTask] to identify all provided [AsserestTestPlatform]
/// subclasses.
final class _AsserestParallelTestTypeSet extends SetBase<AsserestTestPlatform> {
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
    throw UnsupportedError("Look up cannot be performed in this set.");
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

/// Alias [Function] for defining logger in [AsyncExecutor].
typedef void AsyncExecutorLogger(String type, dynamic message,
    [dynamic error, dynamic stackTrace]);

/// A platform for handling multiple [AsserestTestPlatform] to execute at once.
final class AsserestParallelTestPlatform
    extends Iterable<AsserestTestPlatform> {
  /// A [Map] with [AsserestProperty.hashCode] as reference.
  final Map<int, AsserestTestPlatform> _platforms = {};
  final _AsserestParallelTestTypeSet _typeSet = _AsserestParallelTestTypeSet();

  /// Construct a parallel test platform.
  AsserestParallelTestPlatform();

  @override
  Iterator<AsserestTestPlatform<AsserestProperty>> get iterator =>
      _platforms.values.iterator;

  int get length => _platforms.length;

  /// Apply [property] which going to assert.
  void apply(AsserestProperty property) {
    AsserestTestPlatform platform =
        AsserestTestAssigner().buildTestPlatform(property);
    _platforms[(property.hashCode << 2) ^
        (property.runtimeType.hashCode >>> 2)] = platform;
    _typeSet.add(platform);
  }

  /// Perform multiple [apply] with given [properties].
  void applyAll(Iterable<AsserestProperty> properites) {
    properites.forEach(apply);
  }

  /// Wrap all applied [AsserestProperty] into an executor for performing asserion.
  AsserestParallelExecutor buildExecutor(
          {String? name, int threads = 1, AsyncTaskLogger? logger}) =>
      _AsserestParallelExecutor(_platforms.values.toList(), _typeSet, threads,
          name ?? "AsserestParallelExecutor - ${DateTime.now()}", logger);
}

/// An executor for handle assertion on [AsserestProperty].
abstract final class AsserestParallelExecutor {
  const AsserestParallelExecutor._();

  /// Determine does [invoke] called already.
  bool get isInvoked;

  /// Invoke [AsyncExecutor.executeAll] to run all [AsserestTestPlatform] at once.
  ///
  /// This method suppose should be call once only, when [isInvoked] is `true`,
  /// call it again will throw [StateError].
  Stream<AsserestReport> invoke();

  /// Terminate the process of [AsyncExecutor].
  ///
  /// The most ideal way to invoke [shutdown] method is wrapping it into
  /// [StreamSubscription.onDone] or [StreamSubscription.onError].
  Future<bool> shutdown();
}

final class _AsserestParallelExecutor implements AsserestParallelExecutor {
  final AsyncExecutor _executor;
  final UnmodifiableListView<AsserestTestPlatform> _platforms;
  bool _invoked;

  _AsserestParallelExecutor._build(this._executor, this._platforms)
      : _invoked = false;

  factory _AsserestParallelExecutor(
          List<AsserestTestPlatform> platforms,
          Set<AsserestTestPlatform> typeSet,
          int threads,
          String name,
          AsyncExecutorLogger? logger) =>
      _AsserestParallelExecutor._build(
          AsyncExecutor(
              name: name,
              sequential: false,
              parallelism: threads,
              logger: logger,
              taskTypeRegister: typeSet.toList),
          UnmodifiableListView(platforms));

  @override
  Stream<AsserestReport> invoke() {
    if (_invoked) {
      throw StateError("This executor has been invoked already.");
    }

    // Set true immediately to prevent call again in a moment
    _invoked = true;

    return Stream.fromFutures(_executor.executeAll(_platforms));
  }

  @override
  bool get isInvoked => _invoked;

  @override
  Future<bool> shutdown() => _executor.close();
}

/// A [List] extension for [AsserestProperty] that building an [AsserestParallelExecutor]
/// directly.
extension DirectParseParallelExecutor<AP extends AsserestProperty> on List<AP> {
  /// Assign entire items in this [List] to [AsserestParallelExecutor] with bypassing
  /// [AsserestParallelTestPlatform.applyAll].
  AsserestParallelExecutor assignAndBuildExecutor(
      {String? name, int threads = 1, AsyncTaskLogger? logger}) {
    AsserestParallelTestPlatform platform = AsserestParallelTestPlatform()
      ..applyAll(this);

    return platform.buildExecutor(name: name, threads: threads, logger: logger);
  }
}
