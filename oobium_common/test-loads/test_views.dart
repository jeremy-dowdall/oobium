import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/json.dart';

Future<void> main() async {
  final server = Database('server.db');
  server.addBuilder<User>((data) => User.fromJson(data));
  server.addBuilder<Message>((data) => Message.fromJson(server, data));
  await server.open();
  server.putAll([User(id: 'user-joe', name: 'joe'), User(id: 'user-bob', name: 'bob')]);

  final joeClient = Database('joe.db');
  joeClient.addBuilder<User>((data) => User.fromJson(data));
  joeClient.addBuilder<Message>((data) => Message.fromJson(joeClient, data));
  await joeClient.open();
  joeClient.putAll(server.getAll<User>());

  final bobClient = Database('bob.db');
  bobClient.addBuilder<User>((data) => User.fromJson(data));
  bobClient.addBuilder<Message>((data) => Message.fromJson(bobClient, data));
  await bobClient.open();
  bobClient.putAll(server.getAll<User>());

  final joe = bobClient.getAll<User>().firstWhere((u) => u.name == 'joe');
  final bob = bobClient.getAll<User>().firstWhere((u) => u.name == 'bob');
  bobClient.put(Message(from: joe, to: bob, content: 'hey, wassup?'));

  server.putAll(bobClient.getAll());
  joeClient.putAll(server.getAll().where((m) => m is User || (m is Message && (m.from.id == joe.id || m.to.id == joe.id))));

  final messages = joeClient.getAll<Message>();

  print('messages:\n  ${messages.map((m) => m.toJson()).join('\n  ')}');
}

class User extends DataModel {

  final String name;

  User({String id,
    this.name
  }) : super(id);
  User.fromJson(data) :
    name = Json.field(data, 'name'),
    super.fromJson(data)
  ;

  @override
  User copyWith({String id, String name}) => User(
    id: id ?? this.id,
    name: name ?? this.name
  );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['name'] = name
  ;
}

class Message extends DataModel {

  final User from;
  final User to;
  final String content;

  Message({String id,
    this.from,
    this.to,
    this.content,
  }) : super(id);
  Message.fromJson(Database db, data) :
    from = Json.field<User, String>(data, 'from', (v) => db.get<User>(v)),
    to = Json.field<User, String>(data, 'to', (v) => db.get<User>(v)),
    content = Json.field(data, 'content'),
    super.fromJson(data)
  ;

  @override Message copyWith({String id, User from, User to}) => Message(
    id: id ?? this.id,
    from: from ?? this.from,
    to: to ?? this.to
  );

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['from']    = Json.from(from)
    ..['to']      = Json.from(to)
    ..['content'] = Json.from(content)
  ;
}