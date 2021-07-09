import 'dart:io';

import 'package:tools_common/models.dart';

class OobiumHttpOverrides extends HttpOverrides {

  static void set(OobiumProject project) {
    HttpOverrides.global = OobiumHttpOverrides(
        project.host.address,
        project.host.port
    );
  }

  final String host;
  final int port;
  OobiumHttpOverrides(this.host, this.port);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) {
        return host == this.host && port == this.port;
      };
  }
}
