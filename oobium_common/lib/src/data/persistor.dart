export 'persistor_unsupported.dart'
  if (dart.library.io) 'persistor_io.dart'
  if (dart.library.html) 'persistor_html.dart';


class Persistor {

}