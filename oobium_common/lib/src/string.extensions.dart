extension StringExtensions on String {
  static final _letterPattern = RegExp(r'^[a-zA-Z]+$');
  static final _letterOrDigitPattern = RegExp(r'^[0-9a-zA-Z]+$');
  static final _upperCasePattern = RegExp(r'^[A-Z]+$');

  bool get isBlank => isEmptyOrNull || this.trim().isEmpty;
  bool get isNotBlank => !isBlank;
  bool get isEmptyOrNull => this == null || this.isEmpty || this == 'null';
  bool get isLetter => _letterPattern.hasMatch(this);
  bool get isLetterOrDigit => _letterOrDigitPattern.hasMatch(this);
  bool get isUpperCase => _upperCasePattern.hasMatch(this);

  String get initials => (isEmpty) ? '' : splitMapJoin(r'\s+',
      onMatch: (m) => '',
      onNonMatch: (n) => n.isEmpty ? '' : n[0].toUpperCase()
  );

  String orElse(String string) => isBlank ? string : this;

  String get plural {
    if(this == null || this.length == 0) {
      return this;
    }
    if(this.toLowerCase() == "person") {
      return this[0] + "eople";
    }
    if(this.toLowerCase() == "child") {
      return this[0] + "hildren";
    }
    if(this.toLowerCase() == "alumnus") {
      return this[0] + "lumni";
    }
    if('y' == this[this.length-1]) {
      if(this.length > 1) {
        switch(this[this.length-2]) {
          case 'a': case 'e': case 'i': case 'o': case 'u':
          break;
          default:
            return this.substring(0, this.length-1) + "ies";
        }
      }
    }
    if(this.endsWith('ings')) {
      return this;
    }
    if('s' == this[this.length-1]) {
      return this + "es";
    }
    if(this.endsWith('ch')) {
      return this + 'es';
    }
    return this + 's';
  }

  String separated(String separator) {
    String out = '';
    if(this != null && this.isNotEmpty) {
      final c = (separator.length == 1) ? '\\${separator[0]}' : '';
      String s = this.trim().replaceAll(RegExp('[\\s$c]+'), separator);
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

  String get camelCase => underscored.splitMapJoin('_',
      onMatch: (m) => '',
      onNonMatch: (n) => n.isEmpty ? '' : (n.length == 1) ? n.toUpperCase() : '${n[0].toUpperCase()}${n.substring(1).toLowerCase()}'
  );

  String get titleized => underscored.splitMapJoin('_',
    onMatch: (m) => ' ',
    onNonMatch: (n) => n.isEmpty ? '' : (n.length == 1) ? n.toUpperCase() : '${n[0].toUpperCase()}${n.substring(1).toLowerCase()}'
  );

  /// Convert from CamelCase to underscored: MyClassName -> my_class_name.
  ///
  /// null values are returned as an empty String -> ''.
  /// All returned characters are lower case.
  String get underscored => this.separated('_');

  String get varName => isBlank ? '' : (length == 1) ? toLowerCase() : '${this[0].toLowerCase()}${camelCase.substring(1)}';

  String get idField => varName;
}
