extension StringExtensions on String? {
  static final _letterPattern = RegExp(r'^[a-zA-Z]+$');
  static final _letterOrDigitPattern = RegExp(r'^[0-9a-zA-Z]+$');
  static final _upperCasePattern = RegExp(r'^[A-Z]+$');

  bool get isBlank => isEmptyOrNull || this!.trim().isEmpty;
  bool get isNotBlank => !isBlank;
  bool get isEmptyOrNull => this == null || this!.isEmpty || this == 'null';
  bool get isLetter => this != null && _letterPattern.hasMatch(this!);
  bool get isLetterOrDigit => this != null && _letterOrDigitPattern.hasMatch(this!);
  bool get isUpperCase => this != null && _upperCasePattern.hasMatch(this!);

  String get initials => (this.isEmptyOrNull) ? '' : this!.splitMapJoin(r'\s+',
      onMatch: (m) => '',
      onNonMatch: (n) => n.isEmpty ? '' : n[0].toUpperCase()
  );

  String orElse(String string) => isNotBlank ? this! : string;

  String get plural {
    final _this = this;
    if(_this == null || _this.length == 0) {
      return '';
    }
    if(_this.toLowerCase() == "person") {
      return _this[0] + "eople";
    }
    if(_this.toLowerCase() == "child") {
      return _this[0] + "hildren";
    }
    if(_this.toLowerCase() == "alumnus") {
      return _this[0] + "lumni";
    }
    if('y' == _this[_this.length-1]) {
      if(_this.length > 1) {
        switch(_this[_this.length-2]) {
          case 'a': case 'e': case 'i': case 'o': case 'u':
          break;
          default:
            return _this.substring(0, _this.length-1) + "ies";
        }
      }
    }
    if(_this.endsWith('ings')) {
      return _this;
    }
    if('s' == _this[_this.length-1]) {
      return _this + "es";
    }
    if(_this.endsWith('ch')) {
      return _this + 'es';
    }
    return _this + 's';
  }

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
  String get underscored => separated('_');

  String get varName => isBlank ? '' : (this!.length == 1) ? this!.toLowerCase() : '${this![0].toLowerCase()}${camelCase.substring(1)}';

  String get idField => varName;
}
