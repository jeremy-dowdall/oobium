import 'package:flutter/widgets.dart';
import 'package:oobium_client/src/client_auth.dart';
import 'package:oobium_client/src/models.dart';
import 'package:provider/provider.dart';

export 'package:oobium_client/src/auth.dart';
export 'package:oobium_client/src/client_auth.dart';
export 'package:oobium_client/src/models.dart';
export 'package:oobium_client/src/preferences.dart';
export 'package:oobium_client/src/ui/widgets.dart';


extension BuildContextClientExtentions on BuildContext {

  ClientAuth get auth => Provider.of<ClientAuth>(this, listen: false);
  ModelContext get modelContext => Provider.of<ModelContext>(this, listen: false);

}
