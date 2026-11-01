import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/core/images/photo_pipeline.dart';

void main() {
  group('scanOrCamera (spec UC-21: Scan bill)', () {
    var cameraOpened = false;

    Future<String?> camera() async {
      cameraOpened = true;
      return '/camera.jpg';
    }

    setUp(() => cameraOpened = false);

    test('uses the scanned page', () async {
      expect(await scanOrCamera(() async => '/page.jpg', camera), '/page.jpg');
      expect(cameraOpened, isFalse);
    });

    test('cancelling the scanner does not open the camera', () async {
      final path = await scanOrCamera(
        () => throw PlatformException(
          code: 'DocumentScanner',
          message: 'Operation cancelled',
        ),
        camera,
      );
      expect(path, isNull);
      expect(cameraOpened, isFalse);
    });

    test('a phone without the scanner falls back to the camera', () async {
      final path = await scanOrCamera(
        () => throw PlatformException(
          code: 'DocumentScanner',
          message: 'Failed to start document scanner',
        ),
        camera,
      );
      expect(path, '/camera.jpg');
    });

    test('a platform without the plugin falls back to the camera', () async {
      final path = await scanOrCamera(
        () => throw MissingPluginException(),
        camera,
      );
      expect(path, '/camera.jpg');
    });
  });
}
