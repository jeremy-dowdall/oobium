cd ..
echo 'test/model_gen_test.dart'
pub run test test/model_gen_test.dart

echo 'test/string_extensions_test.dart'
pub run test test/string_extensions_test.dart

echo 'test/websocket_test.dart'
pub run test test/websocket_test.dart

echo 'test/database_test.dart'
pub run test test/database_test.dart

echo 'test/database_sync_test.dart'
pub run test test/database_sync_test.dart

echo 'test/string_extensions_test.dart (chrome)'
pub run test -p chrome test/string_extensions_test.dart

echo 'test/websocket_test.dart (chrome)'
pub run test -p chrome test/websocket_test.dart

echo 'test/database_test.dart (chrome)'
pub run test -p chrome test/database_test.dart

echo 'test/database_sync_test.dart (chrome)'
pub run test -p chrome test/database_sync_test.dart
