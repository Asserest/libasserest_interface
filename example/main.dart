import 'dart:collection';

import 'package:async_task/src/async_task_base.dart';
import 'package:async_task/src/async_task_shared_data.dart';
import 'package:libasserest_interface/interface.dart';

final class CustomProperty implements AsserestProperty {
  @override
  final Uri url;

  @override
  final bool accessible;

  @override
  final Duration timeout;

  @override
  final int? tryCount;

  const CustomProperty(this.url, this.accessible, this.timeout,
      [this.tryCount]);
}

final class CustomPropertyParseProcessor
    extends PropertyParseProcessor<CustomProperty> {
  const CustomPropertyParseProcessor();

  @override
  CustomProperty createProperty(Uri url, Duration timeout, bool accessible,
      int? tryCount, UnmodifiableMapView<String, dynamic> additionalProperty) {
    return CustomProperty(url, accessible, timeout, tryCount);
  }

  @override
  Set<String> get supportedSchemes => const <String>{"foo"};
}

final class CustomTestPlatform extends AsserestTestPlatform<CustomProperty> {
  CustomTestPlatform(super.property);

  @override
  AsyncTask<CustomProperty, AsserestReport> instantiate(
          CustomProperty parameters,
          [Map<String, SharedData>? sharedData]) =>
      CustomTestPlatform(property);

  @override
  Future<AsserestResult> runTestProcess() async {
    // Run test here
    return AsserestResult.success;
  }
}

void parallelTestListener(AsserestReport report) {
  // Handle report
}

void main() async {
  AsserestTestAssigner()
    ..assign(CustomProperty,
        (property) => CustomTestPlatform(property as CustomProperty));

  final parallelTester = AsserestParallelTestPlatform();
  parallelTester.applyAll([
    CustomProperty(Uri.parse("foo://example.com"), true, Duration(seconds: 15)),
    CustomProperty(Uri.parse("foo://bar.com"), true, Duration(seconds: 15), 7),
    CustomProperty(Uri.parse("foo://a.com"), false, Duration(seconds: 15))
  ]);

  final executor = parallelTester.buildExecutor();
  executor.invoke().listen(parallelTestListener)
    ..onDone(() async {
      await executor.shutdown();
    })
    ..onError((err) async {
      await executor.shutdown();
    });
}
