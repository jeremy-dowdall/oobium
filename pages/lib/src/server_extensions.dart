import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:oobium_pages/src/html.dart';
import 'package:oobium_server/oobium_server.dart';

extension ResponsePagesX on Response {

  bool get _livePages => request.host.livePages && request.host.settings.isDebug;

  Future<void> render<T>(PageBuilder<T> builder, [T? data]) async {
    if(_livePages) {
      final source = await _findSource(builder.runtimeType.toString(), T.toString());
      if(source != null) {
        return _renderSource(source, data);
      }
    }
    return sendPage(builder.render(path: request.path, data: data));
  }

  Future<void> sendPage(Page page, {int code=200}) => sendHtml(page.render(), code: code);

  Future<String?> _findSource(String builderType, String dataType) async {
    final classDeclaration = 'class $builderType extends PageBuilder<$dataType>';
    final views = Directory('lib/www/views');
    for(var file in (await views.list(recursive: true).toList())) {
      final source = await File(file.path).readAsString();
      if(source.contains(classDeclaration)) {
        return source;
      }
    }
    return null;
  }

  Future<void> _renderSource<T>(String source, T data) async {

    // TODO really just need the imports... it re-compiles / builds everything

    final matches = RegExp(r'class (\w+) extends PageBuilder<(\w+)>').firstMatch(source);
    final builder = matches!.group(1);
    final dataType = matches.group(2);

    final content = '''
      import 'dart:convert';
      import 'dart:isolate';
  
      $source
  
      void main(args, SendPort port) {
        final data = $dataType.fromJson(jsonDecode(args[0]));
        final page = $builder().build(data);
        final html = page.render();
        port.send(html);
      }
    ''';
    print(content);

    final uri = Uri.dataFromString(content, mimeType: 'application/dart');
    final port = ReceivePort();
    final isolate = await Isolate.spawnUri(uri, [jsonEncode(data)], port.sendPort);
    final String html = await port.first;

    port.close();
    isolate.kill();

    return sendHtml(html);
  }
}

class PageData {

  bool get isHome => path == '/';
  bool get isNotHome => !isHome;

  final String page;
  final String path;
  PageData({
    required this.page,
    required this.path
  });
}
