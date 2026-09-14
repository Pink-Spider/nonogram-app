// Driver half of the screenshot harness: writes what the integration test
// captures to build/screenshots/<name>.png.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Directory('build/screenshots');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
