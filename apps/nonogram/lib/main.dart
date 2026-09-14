// Default entry point == dev flavor, so plain `flutter run` works.
// Store builds use `-t lib/main_prod.dart --flavor prod`.
import 'main_dev.dart' as dev;

void main() => dev.main();
