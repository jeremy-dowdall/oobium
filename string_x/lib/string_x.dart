extension StringX on String? {
  static final _digitPattern = RegExp(r'^[0-9]+$');
  static final _letterPattern = RegExp(r'^[a-zA-Z]+$');
  static final _letterOrDigitPattern = RegExp(r'^[0-9a-zA-Z]+$');
  static final _upperCasePattern = RegExp(r'^[A-Z]+$');

  /// true if this is null (including the string 'null'), empty or consists of only whitespace characters
  bool get isBlank => isEmptyOrNull || this!.trim().isEmpty;
  bool get isNotBlank => !isBlank;

  /// true if this is null (including the string 'null'), or empty
  bool get isEmptyOrNull => this == null || this!.isEmpty || this == 'null';

  /// true if this is non-null, non-empty and consists of only digits: [0-9]
  bool get isDigit => this != null && _digitPattern.hasMatch(this!);

  /// true if this is non-null, non-empty and consists of only letters: [a-zA-Z]
  bool get isLetter => this != null && _letterPattern.hasMatch(this!);

  /// true if this is non-null, non-empty and consists of only letters or digits: [0-9a-zA-Z]
  bool get isLetterOrDigit => this != null && _letterOrDigitPattern.hasMatch(this!);

  /// true if this is non-null, non-empty and consists of only upper case letters: [A-Z]
  bool get isUpperCase => this != null && _upperCasePattern.hasMatch(this!);

  /// convert to initials: Foo Bar -> FB, or an empty string if this is blank
  String get initials => this.isBlank ? '' : this!.splitMapJoin(RegExp(r'\s+'),
      onMatch: (m) => '',
      onNonMatch: (n) => n.isEmpty ? '' : n[0].toUpperCase()
  );

  /// return the given string if this is null
  String orElse(String string) => this ?? string;

  /// return the given string if this is blank
  String orIfBlank(String string) => this.isNotBlank ? this! : string;

  String separated(String separator) {
    final _this = this;
    String out = '';
    if(_this != null && _this.isNotEmpty) {
      final c = (separator.length == 1) ? '\\${separator[0]}' : '';
      String s = _this.trim().replaceAll(RegExp('[\\s$c]+'), separator);
      for(int i = 0; i < s.length; i++) {
        if(s[i].isUpperCase) {
          if(i != 0 && s[i-1].isLetterOrDigit) {
            if(s[i-1].isUpperCase) {
              if(i < s.length-1 && s[i+1].isLetter && !s[i+1].isUpperCase) {
                out += separator;
              }
            } else {
              out += separator;
            }
          }
          out += s[i].toLowerCase();
        } else {
          out += s[i];
        }
      }
    }
    return out;
  }

  /// convert to camel case format: foo bar -> FooBar, or an empty string if it is blank
  String get camelCase => underscored.splitMapJoin('_',
    onMatch: (m) => '',
    onNonMatch: (n) => n.isEmpty ? '' : (n.length == 1) ? n.toUpperCase() : '${n[0].toUpperCase()}${n.substring(1).toLowerCase()}'
  );

  /// convert to 'title' format: foo bar -> Foo Bar, or an empty string if it is blank.
  /// similar to camelCase, but each segment is separated by a space
  String get titleized => underscored.splitMapJoin('_',
    onMatch: (m) => ' ',
    onNonMatch: (n) => n.isEmpty ? '' : (n.length == 1) ? n.toUpperCase() : '${n[0].toUpperCase()}${n.substring(1).toLowerCase()}'
  );

  /// convert to underscored format: FooBar -> foo_bar
  String get underscored => separated('_');

  /// convert to a standard variable name format: foo bar -> fooBar.
  /// similar to camelCase, but starting with a lowercase character
  String get varName => isBlank ? '' : (this!.length == 1) ? this!.toLowerCase() : '${this![0].toLowerCase()}${camelCase.substring(1)}';

  String get idField => varName;
}
