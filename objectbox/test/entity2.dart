import 'package:objectbox/objectbox.dart';

// Testing a model for entities in multiple files is generated properly
@Entity()
class TestEntity2 {
  @Id(assignable: true)
  int /*?*/ id;

  TestEntity2({this.id});
}
