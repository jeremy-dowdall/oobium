import 'dart:io';

extension ServerStringsExtensions on List<String> {

  bool matches(List<String> s2) {
    if(length != s2.length) {
      return false;
    }
    for(var i = 0; i < length; i++) {
      if(this[i] != s2[i] && this[i].isNotVariable && s2[i].isNotVariable) {
        return false;
      }
    }
    return true;
  }
}

extension ServerStringExtensions on String {

  String findRouterPath(Iterable<String> routerPaths) {
    final sa = segments;
    for(var path in routerPaths) {
      if(sa.matches(path.segments)) {
        return path;
      }
    }
    return null;
  }

  String get variable => substring(1, length - 1);
  bool get isVariable => this != null && startsWith('<') && endsWith('>');
  bool get isNotVariable => !isVariable;

  Map<String, String> parseParams(String routerPath) {
    final data = <String, String>{};
    final sa = segments;
    final ra = routerPath.segments;
    for(var i = 0; i < sa.length; i++) {
      if(ra[i].isVariable) {
        data[ra[i].variable] = Uri.decodeComponent(sa[i]);
      }
    }
    return data;
  }

  List<String> get segments {
    final sa = split(RegExp(r'[/+]'))..removeWhere((s) => s.isEmpty);
    // print('segments($this) -> $sa');
    return sa;
  }

  List<String> get verifiedSegments {
    final sa = segments;
    for(var s in sa) {
      if(s.contains('><')) throw Exception('contiguous variables are not permitted: \'$this\'');
      if(s == '<>') throw Exception('empty variable segments are not permitted: \'$this\'');
      if(s.contains('<') && !s.contains('>')) throw Exception('variable segments cannot contain a separator [/]: \'$this\'');
    }
    return sa;
  }
}

extension ServerFileExtensions on File {

  ContentType get contentType {
    var index = path.lastIndexOf(RegExp(r'[\./]'));
    final ext = (index == -1) ? path : path.substring(index + 1);
    final result = _contentTypes[ext.toLowerCase()] ?? 'text/plain';
    return ContentType.parse(result);
  }
}

// https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
final _contentTypes = {
  'css':  'text/css',
  'html': 'text/html',
  'js':   'application/javascript',
  'json': 'application/json',
  'gif':  'image/gif',
  'jpeg': 'image/jpeg',
  'jpg':  'image/jpeg',
  'png':  'image/png',
  'svg':  'image/svg+xml',
  'ttf':  'font/ttf',
  'xml':  'text/xml',
  'mp4':  'video/mp4'
};
