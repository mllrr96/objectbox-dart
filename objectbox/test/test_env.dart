import 'dart:io';

import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';

class TestEnv {
  final Directory dir;
  final Store store;

  factory TestEnv(String name) {
    final dir = Directory('testdata-' + name);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    return TestEnv._(dir, Store(getObjectBoxModel(), directory: dir.path));
  }

  TestEnv._(this.dir, this.store);

  Box<TestEntity> get box => store.box();

  void close() {
    store.close();
    if (dir != null && dir /*!*/ .existsSync()) {
      dir /*!*/ .deleteSync(recursive: true);
    }
  }
}

const defaultTimeout = Duration(milliseconds: 1000);

/// "Busy-waits" until the predicate returns true.
bool waitUntil(bool Function() predicate, {Duration timeout = defaultTimeout}) {
  var success = false;
  final until = DateTime.now().add(timeout);

  while (!(success = predicate()) && until.isAfter(DateTime.now())) {
    sleep(Duration(milliseconds: 1));
  }
  return success;
}

/// same as package:test unorderedEquals() but statically typed
Matcher sameAsList<T>(List<T> list) => unorderedEquals(list);

// Yield execution to other isolates.
//
// We need to do this to receive an event in the stream before processing
// the remainder of the test case.
final yieldExecution = () async => await Future<void>.delayed(Duration.zero);
