import 'package:oobium_client_gen/generators/initializers_library_generator.dart';
import 'package:oobium_client_gen/generators/models_library_generator.dart';
import 'package:oobium_client_gen/generators/scaffolding_library_generator.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:test/test.dart';

import 'utils.dart';

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
      final library = InitializersLibraryGenerator().generateLibrary(schema);
      print(library);
    });

    test('models', () {
      final schema = loadBibleStudySchema();
      final library = ModelsLibraryGenerator().generateLibrary(schema);
      print(library);
    });

    test('scaffolding', () {
      final schema = loadBibleStudySchema();
      final library = ScaffoldingLibraryGenerator().generateLibrary(schema);
      print(library);
    });
  });
}

Schema loadBibleStudySchema() => schemaDef([
  classDef('@owner @scaffold User', ['String name', 'String avatar']),
  classDef('@model @scaffold Account', ['String languageId', 'List<String> bibleIds', '@resolve Link<Marker<Account>> bookmark', 'HasMany<Marker> bookmarks']),
  classDef('@model @scaffold Group', ['String name', 'String avatar', 'String description', 'int memberCount', 'Link<Membership> single', 'HasMany<Membership> memberships']),
  classDef('@model @scaffold Membership', ['@resolve Link<Group> group', '@resolve Link<User> user',]),
  classDef('@model @scaffold Message<P>', ['String title', 'String content', 'int color', 'Link<P> parent', 'Access messageAccess', 'HasMany<Marker> markers', 'HasMany<Message> messages',]),
  classDef('@model @scaffold Marker<P>', ['@resolve Link<Bible> bible', '@resolve ChildLink<Book> book', '@resolve ChildLink<Chapter> chapter', '@resolve ChildLink<Verse> verse', 'bool asVerse', 'Link<P> parent',]),
  classDef('@model @scaffold Plan', ['String avatar', 'String name', 'String description', 'Link<Plan> source', 'HasMany<Reading> readings',]),
  classDef('@model @scaffold Reading', ['String title', 'String description', 'String content', 'ReadingResult result', 'Access messageAccess', 'Link<Plan> plan', 'int day', 'int lastDay', 'int index', 'int lastIndex', 'HasMany<Marker> markers', 'HasMany<Message> messages']),
]);
