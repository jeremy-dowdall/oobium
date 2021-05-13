Map<String, String> getParams(String path, String location) {
  final params = <String, String>{};
  final s1 = segments(path);
  final s2 = segments(location);
  for (var i = 0; i < s1.length; i++) {
    if (isVariable(s1[i])) {
      params[s1[i].substring(1, s1[i].length - 1)] = s2[i];
    }
  }
  return params;
}

List<String> segments(String s) =>
    s.split('/').where((e) => e.isNotEmpty).toList();

bool matches(List<String> s1, List<String> s2) {
  for (var i = 0; i < s1.length && i < s2.length; i++) {
    if (s1[i] != s2[i] && isNotVariable(s1[i]) && isNotVariable(s2[i])) {
      return false;
    }
  }
  return true;
}

bool isVariable(String? s) => s != null && s.isNotEmpty && s[0] == '<';

bool isNotVariable(String? s) => !isVariable(s);

class PathUtils {

  final Iterable<String> _paths;

  PathUtils(this._paths);

  String? getMatchingPath(String path, {String? home}) {
    if (path.isNotEmpty) {
      final s = (path == '/' && home != null) ? home : path;
      final sa = segments(s);
      for (final p in _paths) {
        final ka = segments(p);
        if (matches(sa, ka)) {
          if (ka.length == sa.length) {
            return p;
          }
        }
      }
    }
    return null;
  }
}
