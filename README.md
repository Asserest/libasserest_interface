# Standard interface of Asserest execution

Giving the minimal abstract object for constructing Asserest assertion handlers. Especially for proprietary protocol
which prefer to uses with your own implementation or software.

## Aims and comparison with existed methods

## Implementations

<p align="center">This section is for developers who decide to implement from scratch. If you have third-parties implemenataion
already, please refer to <a href="#execution">Execution</a> directly.</p>

To implements assertion with custom protocol, you need to create **at least two objects** before integrate with Asserest.

#### Define property

First, prepare a class which implemented with `AsserestProperty` that to specify properties which going to use.

`AsserestProperty` provides four default properties already that they must denoted with `final` keyword instead of a getter.

**DO**:

```dart
final class CustomProperty implements AsserestProperty {
  @override
  final Uri url;

  @override
  final bool accessible;

  @override
  final Duration timeout;

  @override
  final int? tryCount;

  // Your properties below
}
```

**DON'T**:

```dart
final class CustomProperty implements AsserestProperty {
  @override
  Uri get url;

  @override
  bool get accessible;

  @override
  Duration get timeout;

  @override
  int? get tryCount;

  // Your properties below
}
```

#### Create parse property processor (Optional)

Once your own property has been completed. If you prefer allowing user to parse assertion information via dart's map, you may need to create a parser which based on `PropertyParseProcessor` that all prefedined properties will be converted to corresponded type in Dart already along with unmodifiable map contains non-standarded properties.

There are two methods or getters to be overriden: `createProperty` for parsing map value into actual property object and `supportedSchemes` - A string set specifies which protocol is supported.

```dart
final class CustomPropertyParseProcessor
    extends PropertyParseProcessor<CustomProperty> {
  const CustomParseProcessor();

  @override
  AsserestHttpProperty createProperty(
      Uri url,
      Duration timeout,
      bool accessible,
      int? tryCount,
      UnmodifiableMapView<String, dynamic> additionalProperty) {
   // Create CustomProperty in object.
  }

  @override
  Set<String> get supportedSchemes => const <String>{"foo"};
}
```

#### Test platform

Then, when the parser is ready to uses, you can work on implementing test form by extending `AsserestTestPlatform`.

It only required to override `runTestProcess`, a method corresponded to perform testing and generate assertion result of given URL.

```dart
final class CustomTestPlatform extends AsserestTestPlatform<CustomProperty> {
    Future<AsserestResult> runTestProcess() async {
        // Implement tester here
    }
}
```

## Execution

When the testers are ready to use, there are few predecessor steps to do before perform assertion.

#### Attach with managers

Once you have been implemented tester, it must be registered into `AsserestTestAssigner` in case of applying tester from given tester, especially when performing parallel testing.

Optionally, you can register your own parse processor into `AsserestPropertyParser` that it will generated corresponded type of property depending on URL scheme.

```dart
AsserestPropertyParser().define(CustomParseProcessor());
  AsserestTestAssigner().assign(
      CustomProperty,
      (property) => CustomTestPlatform(property as CustomProperty));
```

If third-parties implementation is planned to be used, please also attach parser and tester as mentioned above unless the developer specified.

### Perform testing

Each testers' property will generated an `AsserestReport` correspondedly which contains assertion result, expectation of URL access, actual result (denotedwith `success`, `failure` and `error` only) and duration of performing test if enabled counting features.

`AsserestParallelTestPlatform` is a class which handles multiple test property and prepare to generate tester in `AsserestParallelExecutor` - a container of testers which execute concurrently that the report will appeared in stream when tester finished it's testing process.

```dart
final testPlatform = AsserestParallelTestPlatform();

testPlatform.assignAll([
    // Properties that going to assigned to test.
]);

final executor = testPlatform.buildExecutor(
    // Optional preferences
    name: "Sample test",
    thread: 6, // Default uses single thread
    logger: null
);
```

You can either using for-loop or attach `StreamSubscription` to handle stream, and don't forget call `shutdown` once the stream is completed:

**Using for-loop**:

```dart
await for (AsserestReport report in executor.invoke()) {
    // Perform the job here.
}

await executor.shutdown();
```

**Using `StreamSubscription`**:

```dart
void reportHandler(AsserestReport report) {
    // Perform the job here.
}

final Stream<AsserestReport> sr = executor.invoke();
sr.listen(reportHandler)
    ..onDone(() async {
        await executor.shutdown();
    })
    ..onError((err) async {
        await executor.shutdown();
    });
```

## License

AGPL-3
