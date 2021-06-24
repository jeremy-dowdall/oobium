import 'dart:io';

import 'package:xstring/xstring.dart';

bool prompt(String question, {String y='y', String n='n', bool defaultIs=false, bool caseSensitive=false}) {
  final text = defaultIs
      ? '[${y.toUpperCase()}|${n.toLowerCase()}]'
      : '[${y.toLowerCase()}|${n.toUpperCase()}]';
  stdout.write('$question $text ');
  String selection;
  bool defaultSelected;
  if(y.length > 1) {
    selection = stdin.readLineSync() ?? '';
    defaultSelected = selection.isBlank;
  } else {
    final wasEcho = stdin.echoMode;
    final wasLine = stdin.lineMode;
    stdin.echoMode = false;
    stdin.lineMode = false;
    final b = stdin.readByteSync();
    if(wasEcho) stdin.echoMode = wasEcho;
    if(wasLine) stdin.lineMode = wasLine;
    selection = String.fromCharCode(b);
    defaultSelected = (b == 10 || b == 13); // LF || CR
    stdout.writeln(defaultSelected ? '' : selection);
  }
  return defaultSelected
      ? defaultIs
      : caseSensitive
          ? (selection == y)
          : (selection.toUpperCase() == y.toUpperCase());
}

String promptFor(String name, {String initial='', bool allowBlank=false, bool echo=true}) {
  final wasEcho = stdin.echoMode;
  if(echo != wasEcho) stdin.echoMode = echo;
  var value = initial;
  stdout.write('$name: [$value] ');
  do {
    final res = stdin.readLineSync()?.trim() ?? '';
    if(allowBlank || res.isNotEmpty) {
      value = res;
    }
  } while(!allowBlank && value.isEmpty);
  if(echo != wasEcho) stdin.echoMode = wasEcho;
  return value;
}
