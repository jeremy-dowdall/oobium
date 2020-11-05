import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_client/src/auth.dart';
import 'package:oobium_client/src/models.dart';

void main() {
  group('test links', () {
    test('test id merged when link resolved', () async {
      final auth = TestAuth();
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      context.register<TestModel>(persistor);
      when(auth.uid).thenReturn('test-id-01');
      when(persistor.get(context, any)).thenAnswer((i) async => TestModel(i.positionalArguments[0], id: i.positionalArguments[1] as String));

      final link = await ChildLink<TestModel>(context, parentId: 'parent-id-01', id: 'test-id-01').resolved();

      expect(link.isResolved, isTrue);
      expect(link.model, isNotNull);
      expect(link.model.id, 'parent-id-01:test-id-01');
    });
  });

  group('test change detection', () {
    test('no changes is sameAs', () {
      final context = TestContext();
      final model1 = TestModel(context, id: 'test-id-01', owner: Link<TestUser>(context, id: 'test-link-01'), access: Access.public);
      final model2 = TestModel(context, id: 'test-id-01', owner: Link<TestUser>(context, id: 'test-link-01'), access: Access.public);
      expect(model1.isSameAs(model2), isTrue);
      expect(model1.isNotSameAs(model2), isFalse);
    });

    test('different ids is notSameAs', () {
      final context = TestContext();
      final model1 = TestModel(context, id: 'test-id-01');
      final model2 = TestModel(context, id: 'test-id-02');
      expect(model1.isSameAs(model2), isFalse);
      expect(model1.isNotSameAs(model2), isTrue);
    });

    test('different access is notSameAs', () {
      final context = TestContext();
      final model1 = TestModel(context, id: 'test-id-01', access: Access.public);
      final model2 = TestModel(context, id: 'test-id-01', access: Access.private);
      expect(model1.isSameAs(model2), isFalse);
      expect(model1.isNotSameAs(model2), isTrue);
    });

    test('different owner.id is notSameAs', () {
      final context = TestContext();
      final model1 = TestModel(context, id: 'test-id-01', owner: Link<TestUser>(context, id: 'test-id-01'));
      final model2 = TestModel(context, id: 'test-id-01', owner: Link<TestUser>(context, id: 'test-id-02'));
      expect(model1.isSameAs(model2), isFalse);
      expect(model1.isNotSameAs(model2), isTrue);
    });
  });

  group('test model context', () {
    test('test without registered builder and persistor', () {
      final context = ModelContext(null);
      expect(context.canBuild(TestModel), isFalse);
      expect(context.cannotBuild(TestModel), isTrue);
      expect(context.canPersist(TestModel), isFalse);
      expect(context.cannotPersist(TestModel), isTrue);
    });

    test('test with builder registered', () {
      final context = ModelContext(null);
      context.addBuilder<TestModel>((context, data) => TestModel(context));
      expect(context.canBuild(TestModel), isTrue);
      expect(context.cannotBuild(TestModel), isFalse);
      expect(context.canPersist(TestModel), isFalse);
      expect(context.cannotPersist(TestModel), isTrue);
    });

    test('test with persistor registered', () {
      final context = ModelContext(null);
      context.register<TestModel>(TestPersistor());
      expect(context.canBuild(TestModel), isFalse);
      expect(context.cannotBuild(TestModel), isTrue);
      expect(context.canPersist(TestModel), isTrue);
      expect(context.cannotPersist(TestModel), isFalse);
    });

    test('test with builder and persistor registered', () {
      final context = ModelContext(null);
      context.addBuilder<TestModel>((context, data) => TestModel(context));
      context.register<TestModel>(TestPersistor());
      expect(context.canBuild(TestModel), isTrue);
      expect(context.cannotBuild(TestModel), isFalse);
      expect(context.canPersist(TestModel), isTrue);
      expect(context.cannotPersist(TestModel), isFalse);
    });
  });

  group('test model owner', () {
    test('test model owner from default constructor', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context);
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from null constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, owner: null);
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from empty link constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, owner: Link<TestUser>(context));
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from link constructor value with different id', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, owner: Link<TestUser>(context, id: 'test-user-02'));
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-02');
    });

    test('test model owner from json constructor', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, null);
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from null json constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'ownerId': null});
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from empty link json constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'ownerId': ''});
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-01');
    });

    test('test model owner from link json constructor value with different id', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'ownerId': 'test-user-02'});
      expect(testModel.owner is Link<TestUser>, isTrue);
      expect(testModel.owner.id, 'test-user-02');
    });
  });

  group('test model access', () {
    test('test model access from default constructor', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context);
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
      expect(testModel.access.toJsonString(), null);
    });

    test('test model access from null constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, access: null);
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
    });

    test('test model access from private constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, access: Access.private);
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
      when(context.uid).thenReturn('test-user-02');
      expect(testModel.access.isGranted, isFalse);
    });

    test('test model access from public constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel(context, access: Access.public);
      expect(testModel.access is PublicAccess, isTrue);
      expect(testModel.access.isGranted, isTrue);
    });

    test('test model access from json constructor', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, null);
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
    });

    test('test model access from null json constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'access': null});
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
    });

    test('test model access from empty json constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'access': ''});
      expect(testModel.access is PrivateAccess, isTrue);
      expect((testModel.access as PrivateAccess).ownerId, 'test-user-01');
      expect(testModel.access.isGranted, isTrue);
    });

    test('test model access from public json constructor value', () {
      final context = TestContext();
      when(context.uid).thenReturn('test-user-01');
      final testModel = TestModel.fromJson(context, {'access': 'public'});
      expect(testModel.access is PublicAccess, isTrue);
      expect(testModel.access.isGranted, isTrue);
    });
  });

  group('test model observer', () {
    test('test onGet observer', () async {
      final auth = TestAuth();
      when(auth.uid).thenReturn('test-id-01');
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      final observer = TestObserver();
      final model = TestModel(context, id: 'test-id-01');
      context.register<TestModel>(persistor);
      when(persistor.get<TestModel>(context, 'test-id-01')).thenAnswer((_) async => model);

      context.observe<TestModel>(onGet: observer.onGet);
      await context.get<TestModel>('test-id-01');

      expect(model, verify(observer.onGet(captureAny)).captured[0]);
    });

    test('test onSave observer', () async {
      final auth = TestAuth();
      when(auth.uid).thenReturn('test-id-01');
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      final observer = TestObserver();
      final model = TestModel(context, id: 'test-id-01');
      context.register<TestModel>(persistor);
      when(persistor.save(model)).thenAnswer((_) async => SaveResult.success([model]));

      context.observe<TestModel>(onSave: observer.onSave);
      await model.save();

      expect(model, verify(observer.onSave(captureAny)).captured[0]);
    });

    test('test onSave observer', () async {
      final auth = TestAuth();
      when(auth.uid).thenReturn('test-id-01');
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      final observer = TestObserver();
      final model = TestModel(context, id: 'test-id-01');
      context.register<TestModel>(persistor);
      when(persistor.get<TestModel>(context, 'test-id-01')).thenAnswer((_) async => model);
      when(persistor.save(model)).thenAnswer((_) async => SaveResult.success([model]));
      when(persistor.delete(model)).thenAnswer((_) async => true);

      context.observe<TestModel>(onDelete: observer.onDelete);
      await model.delete();

      expect(model, verify(observer.onDelete(captureAny)).captured[0]);
    });

    test('test all observer', () async {
      final auth = TestAuth();
      when(auth.uid).thenReturn('test-id-01');
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      final observer = TestObserver();
      final model = TestModel(context, id: 'test-id-01');
      context.register<TestModel>(persistor);
      when(persistor.get<TestModel>(context, 'test-id-01')).thenAnswer((_) async => model);
      when(persistor.save(model)).thenAnswer((_) async => SaveResult.success([model]));
      when(persistor.delete(model)).thenAnswer((_) async => true);

      context.observe<TestModel>(all: observer.onGet);
      await context.get<TestModel>('test-id-01');
      await model.save();
      await model.delete();

      verify(observer.onGet(model)).called(3);
    });

    test('test remove observer', () async {
      final auth = TestAuth();
      when(auth.uid).thenReturn('test-id-01');
      final persistor = TestPersistor();
      final context = ModelContext(auth);
      final observer = TestObserver();
      final model = TestModel(context, id: 'test-id-01');
      context.register<TestModel>(persistor);
      when(persistor.get<TestModel>(context, 'test-id-01')).thenAnswer((_) async => model);

      context.observe<TestModel>(onGet: observer.onGet);
      await context.get<TestModel>('test-id-01');

      expect(model, verify(observer.onGet(captureAny)).captured[0]);

      context.removeObservers<TestModel>();
      await context.get<TestModel>('test-id-01');

      verifyNever(observer.onGet(any));
    });
  });
}

abstract class Observer<T> {
  void onGet (T model);
  void onSave (T model);
  void onDelete (T model);
}
class TestObserver<T> extends Mock implements Observer<T> { }

class TestAuth extends Mock implements Auth { }
class TestContext extends Mock implements ModelContext { }
class TestPersistor extends Mock implements Persistor { }

class TestModel extends Model<TestModel, TestUser> {
  TestModel(ModelContext context, {String id, Link owner, Access access}) : super(context, id, owner, access);
  TestModel.fromJson(ModelContext context, data) : super.fromJson(context, data);
  @override copyWith({String id, Link owner, Access access}) => throw UnimplementedError();
}

class TestUser extends Model<TestUser, TestUser> {
  TestUser(ModelContext context, {String id, Link owner, Access access}) : super(context, id, owner, access);
  TestUser.fromJson(ModelContext context, data) : super.fromJson(context, data);
  @override copyWith({String id, Link owner, Access access}) => throw UnimplementedError();
}
