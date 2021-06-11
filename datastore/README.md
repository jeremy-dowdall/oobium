# Oobium DataStore
[![pub package](https://img.shields.io/pub/v/oobium_datastore.svg)](https://pub.dev/packages/oobium_datastore)

Data for Flutter...

# Usage
To use this plugin, add `oobium_datastore` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).
To use the code generation features, add `oobium_datastore_gen` as a [dev dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

# Example
## Create a schema, generate your datastore and models

main.schema:
```shell script
Author
  name String

Book
  title String
  author Author
```

```shell script
# dart
> dart run build_runner build

# flutter
> flutter pub run build_runner build
```

```dart
import 'package:oobium_datastore/oobium_datastore.dart';

void main() {
  // TODO
}
```
