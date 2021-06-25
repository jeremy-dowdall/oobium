enum Level { fine, info, warning, error, }
extension LevelX on Level {
  String get name => toString().split('.')[1];
}

class Logger {

  final String name;
  Logger(this.name);

  var level = Level.warning;

  void error(message) => call(Level.error, message);
  void warning(message) => call(Level.warning, message);
  void info(message) => call(Level.info, message);
  void fine(message) => call(Level.fine, message);

  void call(Level level, message) {
    if(level.index >= this.level.index) {
      final time = DateTime.now().millisecondsSinceEpoch;
      if(message is Function) {
        message = message();
      }
      print('$name(${level.name}): $time: ${message}');
    }
  }
}