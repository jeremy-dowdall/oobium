import 'dart:html' hide WebSocket;
import 'dart:indexed_db';

import 'package:oobium_common/src/data/data.dart';
import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/data/models.dart';
import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/websocket.dart';

import 'sync_base.dart' as base;

class Sync extends base.Sync {

  Sync(Data db, Repo repo, [Models models]) : super(db, repo, models);

  Database idb;
  final executor = Executor();

  @override
  Future<Sync> open() async {
    idb = db.connect(this);
    return this;
  }

  @override
  Future<void> save() async {
    print('TODO save (html)');
  }
}

class Replicant extends base.Replicant {

  Replicant(Data db, String id) : super(db, id);

}
