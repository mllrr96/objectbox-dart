import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  /*late final*/ TestEnv env;
  /*late final*/
  Box<TestEntity> box;

  setUp(() {
    env = TestEnv('query');
    box = env.box;
  });

  test('Query with no conditions, and order as desc ints', () {
    box.putMany(<TestEntity>[
      TestEntity(tInt: 0),
      TestEntity(tInt: 10),
      TestEntity(tInt: 100),
      TestEntity(tInt: 10),
      TestEntity(tInt: 0),
    ]);

    var query =
        box.query().order(TestEntity_.tInt, flags: Order.descending).build();
    final listDesc = query.find();
    query.close();

    expect(listDesc.map((t) => t.tInt).toList(), [100, 10, 10, 0, 0]);
  });

  test('ignore transient field', () {
    box.put(TestEntity(tDouble: 0.1, ignore: 1337));

    final d = TestEntity_.tDouble;

    final q = box.query(d.between(0.0, 0.2)).build();

    expect(q.count(), 1);
    expect(q.findFirst().ignore, null);

    q.close();
  });

  test('ignore multiple transient fields', () {
    final entity = TestEntity.ignoredExcept(1337);

    box.put(entity);

    expect(entity.omit, -1);
    expect(entity.disregard, 1);

    final i = TestEntity_.tInt;

    final q = box.query(i.equals(1337)).build();

    final result = q.findFirst();

    expect(q.count(), 1);
    expect(result.disregard, null);
    expect(result.omit, null);

    q.close();
  });

  test('.null and .notNull', () {
    box.putMany(<TestEntity>[
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
      TestEntity(tString: 'one'),
      TestEntity(tString: 'two'),
    ]);

    final b = TestEntity_.tBool;
    final t = TestEntity_.tString;

    final qbNull = box.query(b.isNull()).build();
    final qbNotNull = box.query(b.notNull()).build();
    final qtNull = box.query(t.isNull()).build();
    final qtNotNull = box.query(t.notNull()).build();
    final qdNull = box.query(t.isNull()).build();
    final qdNotNull = box.query(t.notNull()).build();

    [qbNull, qbNotNull, qtNull, qtNotNull, qdNull, qdNotNull].forEach((q) {
      expect(q.count(), 2);
      q.close();
    });
  });

  test('.count doubles and booleans', () {
    box.putMany(<TestEntity>[
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
      TestEntity(tDouble: 0.5, tBool: true),
      TestEntity(tDouble: 0.7, tBool: false),
      TestEntity(tDouble: 0.9, tBool: true)
    ]);

    final d = TestEntity_.tDouble;
    final b = TestEntity_.tBool;

    final anyQuery0 = (d.between(0.79, 0.81) & b.equals(false) |
        (d.between(0.69, 0.71) & b.equals(false)));
    final anyQuery1 = (d.between(0.79, 0.81).and(b.equals(false)))
        .or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery2 = d
        .between(0.79, 0.81)
        .and(b.equals(false))
        .or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery3 = d
        .between(0.79, 0.81)
        .and(b.equals(false))
        .or(d.between(0.69, 0.71))
        .and(b.equals(false));

    final allQuery0 = d.between(0.09, 0.11) & b.equals(true);

    final q0 = box.query(b.equals(false)).build();
    final qany0 = box.query(anyQuery0).build();
    final qany1 = box.query(anyQuery1).build();
    final qany2 = box.query(anyQuery2).build();
    final qany3 = box.query(anyQuery3).build();

    final qall0 = box.query(allQuery0).build();

    expect(q0.count(), 2);
    expect(qany0.count(), 1);
    expect(qany1.count(), 1);
    expect(qany2.count(), 1);
    expect(qany3.count(), 1);
    expect(qall0.count(), 1);

    [q0, qany0, qany1, qany2, qany3, qall0].forEach((q) => q.close());
  });

  test('.count matches of `greater` and `less`', () {
    box.putMany(<TestEntity>[
      TestEntity(tLong: 1336, tString: 'mord'),
      TestEntity(tLong: 1337, tString: 'more'),
      TestEntity(tLong: 1338, tString: 'morf'),
      TestEntity(tDouble: 0.0, tBool: false),
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.2, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
    ]);

    final d = TestEntity_.tDouble;
    final b = TestEntity_.tBool;
    final t = TestEntity_.tString;
    final n = TestEntity_.tLong;

    final checkQueryCount = (int expectedCount, Condition condition) {
      final query = box.query(condition).build();
      expect(query.count(), expectedCount);
      query.close();
    };

    checkQueryCount(2, b.equals(false));
    checkQueryCount(1, t.greaterThan('more'));
    checkQueryCount(1, t.lessThan('more'));
    checkQueryCount(2, d.greaterThan(0.1));
    checkQueryCount(3, d.greaterOrEqual(0.1));
    checkQueryCount(3, d.lessThan(0.3));
    checkQueryCount(4, d.lessOrEqual(0.3));
    checkQueryCount(1, n.lessThan(1337));
    checkQueryCount(2, n.lessOrEqual(1337));
    checkQueryCount(1, n.greaterThan(1337));
    checkQueryCount(2, n.greaterOrEqual(1337));
  });

  test('.count matches of `in`, `contains`', () {
    box.put(TestEntity(tLong: 1337, tString: 'meh'));
    box.put(TestEntity(tLong: 1, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'blh'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    final qs0 = box.query(text.inside(['meh'])).build();
    final qs1 = box.query(text.inside(['bleh'])).build();
    final qs2 = box.query(text.inside(['meh', 'bleh'])).build();
    final qs3 = box.query(text.contains('eh')).build();

    final qn0 = box.query(number.inside([1])).build();
    final qn1 = box.query(number.inside([1337])).build();
    final qn2 = box.query(number.inside([1, 1337])).build();

    expect(qs0.count(), 1);
    expect(qs1.count(), 2);
    expect(qs2.count(), 3);
    expect(qs3.count(), 3);
    expect(qn0.count(), 1);
    expect(qn1.count(), 3);
    expect(qn2.count(), 4);

    [qs0, qs1, qs2, qs3, qn0, qn1, qn2].forEach((q) => q.close());
  });

  test('.count matches of List<String> `contains`', () {
    box.put(TestEntity(tStrings: ['foo', 'bar']));
    box.put(TestEntity(tStrings: ['barbar']));
    box.put(TestEntity(tStrings: ['foo']));

    final prop = TestEntity_.tStrings;

    final qs0 = box.query(prop.contains('bar')).build();
    expect(qs0.count(), 1);

    final qs1 = box.query(prop.contains('ar')).build();
    expect(qs1.count(), 0);

    final qs2 = box.query(prop.contains('foo')).build();
    expect(qs2.count(), 2);

    [qs0, qs1, qs2].forEach((q) => q.close());
  });

  test('.findIds returns List<int>', () {
    box.put(TestEntity(tString: null));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'helb'));
    box.put(TestEntity(tString: 'helb'));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'blh'));

    final text = TestEntity_.tString;

    final q0 = box.query(text.notNull()).build();
    final result0 = q0.findIds();

    final q2 = box.query(text.equals('blh')).build();
    final result2 = q2.findIds();

    final q3 = box.query(text.equals("can't find this")).build();
    final result3 = q3.findIds();

    expect(result0, sameAsList([2, 3, 4, 5, 6, 7]));
    expect(result2, sameAsList([7]));
    expect(result3.isEmpty, isTrue);

    q0.close();
    q2.close();
    q3.close();

    // paranoia
    [result0, result2, result3].forEach((ids) => ids.forEach((id) {
          final read = box.get(id);
          expect(read, isNotNull);
          expect(read.id, equals(id));
        }));
  });

  test('.find offset and limit', () {
    box.put(TestEntity());
    box.put(TestEntity(tString: 'a'));
    box.put(TestEntity(tString: 'b'));
    box.put(TestEntity(tString: 'c'));

    var q = box.query().build();
    expect(q.find().length, 4);

    expect(q.offset(2).find().map((e) => e.tString), equals(['b', 'c']));
    expect(q.limit(1).find().map((e) => e.tString), equals(['b']));
    expect(q.offset(0).find().map((e) => e.tString), equals([null]));

    q.close();
  });

  test('.findFirst returns TestEntity', () {
    box.put(TestEntity(tLong: 0));
    box.put(TestEntity(tString: 'test1t'));
    box.put(TestEntity(tString: 'test'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    final c = text.startsWith('t') & text.endsWith('t');

    var q = box.query(c).build();

    expect(q.findFirst().tString, 'test1t');
    q.close();

    q = box.query(number.notNull()).build();
    expect(q.findFirst().tLong, 0);
    q.close();
  });

  test('.find works on large arrays', () {
    // This would fail on 32-bit system if objectbox-c obx_supports_bytes_array() wasn't respected
    final length = 10 * 1000;
    final largeString = 'A' * length;
    expect(largeString.length, length);

    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));

    final query = box.query(TestEntity_.id.lessThan(3)).build();
    List<TestEntity> items = query.find();
    expect(items.length, 2);
    expect(items[0].tString, largeString);
    expect(items[1].tString, largeString);
    query.close();
  });

  test('.remove deletes the right items', () {
    box.put(TestEntity());
    box.put(TestEntity(tString: 'test'));
    box.put(TestEntity(tString: 'test3'));
    box.put(TestEntity(tString: 'foo'));

    final text = TestEntity_.tString;

    final q = box.query(text.startsWith('test')).build();
    expect(q.remove(), 2);
    q.close();

    final remaining = box.getAll();
    expect(remaining.length, 2);
    expect(remaining.map((e) => e.id), equals([1, 4]));
  });

  test('.count items after grouping with and/or', () {
    box.put(TestEntity(tString: 'Hello'));
    box.put(TestEntity(tString: 'Goodbye'));
    box.put(TestEntity(tString: 'World'));

    box.put(TestEntity(tLong: 1337));
    box.put(TestEntity(tLong: 80085));

    box.put(TestEntity(tLong: -1337, tString: 'meh'));
    box.put(TestEntity(tLong: -1332 + -5, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'Goodbye'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    Condition cond1 = text.equals('Hello') | number.equals(1337);
    Condition cond2 = text.equals('Hello') | number.equals(1337);
    Condition cond3 =
        text.equals('What?').and(text.equals('Hello')).or(text.equals('World'));
    Condition cond4 = text
        .equals('Goodbye')
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals('Cruel'))
        .or(text.equals('World'));
    Condition cond5 = text.equals('bleh') & number.equals(-1337);
    Condition cond6 = text.equals('Hello') & number.equals(1337);

    final q1 = box.query(cond1).build();
    final q2 = box.query(cond2).build();
    final q3 = box.query(cond3).build();
    final q4 = box.query(cond4).build();
    final q5 = box.query(cond5).build();
    final q6 = box.query(cond6).build();

    expect(q1.count(), 3);
    expect(q2.count(), 3);
    expect(q3.count(), 1);
    expect(q4.count(), 3);
    expect(q5.count(), 1);
    expect(q6.count(), 0);

    [q1, q2, q3, q4, q5, q6].forEach((q) => q.close());
  });

  test('.describe query', () {
    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;
    Condition c = text
        .equals('Goodbye')
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals('Cruel'))
        .or(text.equals('World'));
    final q = box.query(c).build();
    // 5 partial conditions, + 1 'and' + 1 'any' = 7 conditions
    // note: order of properties is not guaranteed (currently OS specific).
    expect(
        q.describe(),
        matches(
            'Query for entity TestEntity with 7 conditions with properties (tLong, tString|tString, tLong)'));
    q.close();

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Hello');
      for (var i = 0; i < j; i++) {
        tc = tc.or(text.endsWith('lo'));
      }
      final q = box.query(tc).build();
      expect(q.describe(),
          '''Query for entity TestEntity with ${j + 2} conditions with properties tString''');
      q.close();
    }

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Hello');
      for (var i = 0; i < j; i++) {
        tc = tc.and(text.startsWith('lo'));
      }
      final q = box.query(tc).build();
      expect(q.describe(),
          '''Query for entity TestEntity with ${j + 2} conditions with properties tString''');
      q.close();
    }
  });

  test('query condition grouping', () {
    final n = TestEntity_.id;
    final b = TestEntity_.tBool;

    final check = (Condition condition, String text) {
      final q = box.query(condition).build();
      expect(q.describeParameters(), text);
      q.close();
    };

    check((n.equals(0) & b.equals(false)) | (n.equals(1) & b.equals(true)),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n AND tBool == 1))');
    check(n.equals(0) & b.equals(false) | n.equals(1) & b.equals(true),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n AND tBool == 1))');
    check((n.equals(0) & b.equals(false)) | (n.equals(1) | b.equals(true)),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n OR tBool == 1))');
    check((n.equals(0) & b.equals(false)) | n.equals(1) | b.equals(true),
        '((id == 0\n AND tBool == 0)\n OR id == 1\n OR tBool == 1)');
    check(n.equals(0) | b.equals(false) & n.equals(1) | b.equals(true),
        '(id == 0\n OR (tBool == 0\n AND id == 1)\n OR tBool == 1)');
  });

  test('.describeParameters query', () {
    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;
    Condition c = text
        .equals('Goodbye')
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals('Cruel'))
        .or(text.equals('World'));
    final q = box.query(c).build();
    final expectedString = [
      '''((tString ==(i) "Goodbye"''',
      ''' AND tLong == 1337)''',
      ''' OR tLong == 1337''',
      ''' OR tString ==(i) "Cruel"''',
      ''' OR tString ==(i) "World")'''
    ].join('\n');
    expect(q.describeParameters(), expectedString);
    q.close();

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Goodbye');
      var expected = ['''tString ==(i) "Goodbye"'''];
      for (var i = 0; i < j; i++) {
        tc = tc.and(text.endsWith('ye'));
        expected.add(''' AND tString ends with(i) "ye"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Goodbye');
      var expected = ['''tString ==(i) "Goodbye"'''];
      for (var i = 0; i < j; i++) {
        tc = tc.or(text.startsWith('Good'));
        expected.add(''' OR tString starts with(i) "Good"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }
  });

  test('.order queryBuilder', () {
    box.put(TestEntity(tString: 'World'));
    box.put(TestEntity(tString: 'Hello'));
    box.put(TestEntity(tString: 'HELLO'));
    box.put(TestEntity(tString: 'World'));
    box.put(TestEntity(tString: 'Goodbye'));
    box.put(TestEntity(tString: 'Cruel'));
    box.put(TestEntity(tLong: 1337));

    final text = TestEntity_.tString;

    final condition = text.notNull();

    final query = box.query(condition).order(text).build();
    final result1 = query.find().map((e) => e.tString).toList();

    expect('Cruel', result1[0]);
    expect('Hello', result1[2]);
    expect('HELLO', result1[3]);

    final queryReverseOrder = box
        .query(condition)
        .order(text, flags: Order.descending | Order.caseSensitive)
        .build();
    final result2 = queryReverseOrder.find().map((e) => e.tString).toList();

    expect('World', result2[0]);
    expect('Hello', result2[2]);
    expect('HELLO', result2[3]);

    query.close();
    queryReverseOrder.close();
  });

  test('.describeParameters BytesVector', () {
    final q = box
        .query(TestEntity_.tUint8List.equals([1, 2]) &
            TestEntity_.tInt8List.greaterThan([3, 4]) &
            TestEntity_.tByteList.greaterOrEqual([5, 6, 7]) &
            TestEntity_.tUint8List.lessThan([8]) &
            TestEntity_.tUint8List.lessOrEqual([9, 10, 11, 12]))
        .build();
    expect(
        q.describeParameters(),
        equals('(tUint8List == byte[2]{0x0102}\n'
            ' AND tInt8List > byte[2]{0x0304}\n'
            ' AND tByteList >= byte[3]{0x050607}\n'
            ' AND tUint8List < byte[1]{0x08}\n'
            ' AND tUint8List <= byte[4]{0x090A0B0C})'));
    q.close();
  });

  tearDown(() {
    env.close();
  });
}
