import 'package:oobium_gen/src/generators.dart';
import 'package:oobium_gen/src/util/schema.dart';
import 'package:oobium_gen/src/util/schema_builder.dart';
import 'package:oobium_gen/src/util/schema_library.dart';
import 'package:test/test.dart';

void main() {
  group('test bible-study', () {
    test('schema', () {
      final schema = loadBibleStudySchema();
      expect(schema.models.length, 8);
      final models = schema.models;
      final User = models[0], Account = models[1], Group = models[2], Membership = models[3], Message = models[4], Marker = models[5], Plan = models[6], Reading = models[7];
      expect(Message.isGeneric, isTrue);
      expect(Message.fields[5].model.type, 'Message<P>');
      expect(Message.fields[5].type, 'HasMany<Marker<Message>>');
      expect(Message.fields[5].name, 'markers');
      expect(Message.expanded[0].fields[5].model.type, 'Message<Message>');
      expect(Message.expanded[0].fields[5].type, 'HasMany<Marker<Message>>');
      expect(Message.expanded[0].fields[5].name, 'markers');
      expect(Message.expanded[0].fields[5].linkedModel.type, 'Marker<Message>');
      expect(Message.expanded[0].fields[5].linkedField.type, 'Link<Message<Marker>>');
      expect(Message.expanded[0].fields[5].linkedField.name, 'parent');
      expect(Marker.isGeneric, isTrue);
    });

    test('initializers', () {
      final schema = loadBibleStudySchema();
      final library = generateInitializersLibrary(schema, 'models.dart');
      print(library);
    });

    test('models', () {
      final schema = loadBibleStudySchema();
      final library = generateModelsLibrary(schema);
      print(library);
    });

    test('scaffolding', () {
      final schema = loadBibleStudySchema();
      final library = generateScaffoldingLibrary(schema, 'models.dart');
      print(library);
    });
  });
}

Schema loadBibleStudySchema() => SchemaBuilder(SchemaLibrary.parse([
  'User(owner, scaffold)', '  name String', '  avatar String',
  'Account(scaffold)', '  languageId String', '  bibleIds List<String>', '  bookmark Link<Marker<Account>>(resolve)', '  bookmarks HasMany<Marker>',
  'Group(scaffold)', '  name String', '  avatar String', '  description String', '  memberCount int', '  single Link<Membership>', '  memberships HasMany<Membership>',
  'Membership(scaffold)', '  group Link<Group>(resolve)', '  user Link<User>(resolve)',
  'Message<P>(scaffold)', '  title String', '  content String', '  color int', '  parent Link<P>', '  messageAccess Access', '  markers HasMany<Marker>', '  messages HasMany<Message>',
  'Marker<P>(scaffold)', '  bible Link<Bible>(resolve)', '  book ChildLink<Book>(resolve)', '  chapter ChildLink<Chapter>(resolve)', '  verse ChildLink<Verse>(resolve)', '  asVerse bool', '  parent Link<P>',
  'Plan(scaffold)', '  avatar String', '  name String', '  description String', '  source Link<Plan>', '  readings HasMany<Reading>',
  'Reading(scaffold)', '  title String', '  description String', '  content String', '  result ReadingResult', '  messageAccess Access', '  plan Link<Plan>', '  day int', '  lastDay int', '  index int', '  lastIndex int', '  markers HasMany<Marker>', '  messages HasMany<Message>',
])).build();
