import 'package:flutter/widgets.dart';
import 'package:oobium_client/src/auth.dart';
import 'package:oobium_client/src/models.dart';
import 'package:oobium_client/src/preferences.dart';
import 'package:provider/provider.dart';

export 'package:oobium_client/src/auth.dart';
export 'package:oobium_client/src/models.dart' hide ModelBuilder;
export 'package:oobium_client/src/preferences.dart';
export 'package:oobium_client/src/ui/widgets.dart';

extension BuildContextClientExtentions on BuildContext {

  Auth get auth => Provider.of<Auth>(this, listen: false);
  ModelContext get modelContext => Provider.of<ModelContext>(this, listen: false);
  Preferences get preferences => Provider.of<Preferences>(this, listen: false);

}
