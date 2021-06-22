import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:oobium_pages/src/html.dart';
import 'package:oobium_server/oobium_server.dart';

class PageResponse extends HtmlResponse {
  final PageBuilder? builder;
  final String? dataType;
  PageResponse(Page page, {int code=200}) : this._(builder: null, data: page.render(), code: code);
  static PageResponse render<T>(PageBuilder<T> builder, [T? data]) {
    return PageResponse._(builder: builder, data: data, dataType: '$T');
  }
  PageResponse._({this.builder, this.dataType, int code=200, data}) : super(data, code: code);

  @override
  FutureOr<dynamic> resolve(Request request) async {
    if(builder == null) {
      return '$data';
    }
    if(request.livePages) {
      return _render(request, builder!, dataType!);
    }
    return builder!.render(path: request.path, data: data).render();
  }

  Future<dynamic> _render(Request request, PageBuilder builder, String dataType) async {
    final source = await _findSource(builder.runtimeType.toString(), dataType);
    if(source != null) {
      return _renderSource(source, data);
    }
  }

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

  Future<String> _renderSource<T>(String source, T data) async {

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

    return html;
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
