/// Platform resource integrity (Phase 6).
///
/// Phase 6 fixed web icon references that pointed at non-existent files,
/// added Android adaptive icons, and regenerated the iOS Podfile. These
/// tests pin the cross-platform resource graph so a future rename or
/// missing density fails CI instead of silently shipping a broken icon.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the pixel dimensions of a PNG from its IHDR chunk.
List<int> pngDimensions(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThan(24), reason: '${file.path} too small');
  expect(
    String.fromCharCodes(bytes.sublist(1, 4)),
    'PNG',
    reason: '${file.path} is not a PNG',
  );
  final byteData = bytes.buffer.asByteData();
  return [
    byteData.getUint32(16), // width
    byteData.getUint32(20), // height
  ];
}

void main() {
  // `flutter test` runs with the project root as the working directory.
  final root = Directory.current.path;

  group('web manifest', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      final file = File('$root/web/manifest.json');
      expect(file.existsSync(), isTrue, reason: 'web/manifest.json missing');
      manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('declares VaaniX branding (no template leftovers)', () {
      expect(manifest['name'], 'VaaniX');
      expect(manifest['short_name'], 'VaaniX');
      expect(
        manifest['description'] as String,
        isNot(contains('A new Flutter project')),
      );
    });

    test('every declared icon exists with the declared size', () {
      final icons = manifest['icons'] as List<dynamic>;
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        final src = icon['src'] as String;
        final file = File('$root/web/$src');
        expect(file.existsSync(), isTrue,
            reason: 'manifest icon $src does not exist');
        final declared = (icon['sizes'] as String).split('x');
        final actual = pngDimensions(file);
        expect(actual[0], int.parse(declared[0]), reason: '$src width');
        expect(actual[1], int.parse(declared[1]), reason: '$src height');
      }
    });
  });

  group('web index.html', () {
    test('all referenced assets exist', () {
      final html = File('$root/web/index.html').readAsStringSync();
      final refs = RegExp(
        r'(?:href|content)="([^"]+\.png|[^"]+\.json)"',
      ).allMatches(html).map((m) => m.group(1)!);
      expect(refs, isNotEmpty);
      for (final ref in refs) {
        expect(
          File('$root/web/$ref').existsSync(),
          isTrue,
          reason: 'index.html references missing asset: $ref',
        );
      }
    });

    test('apple-touch-icon points at a file that ships', () {
      // Regression: the template referenced icons/Icon-192.png which was
      // never committed — only the maskable variants exist.
      final html = File('$root/web/index.html').readAsStringSync();
      expect(html, isNot(contains('icons/Icon-192.png')));
      expect(html, isNot(contains('icons/Icon-512.png')));
    });
  });

  group('android adaptive icon', () {
    test('anydpi-v26 descriptor exists and resolves both layers', () {
      final xml = File(
        '$root/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
    });

    test('background color resource is defined', () {
      final colors = File(
        '$root/android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();
      expect(colors, contains('ic_launcher_background'));
    });

    test('foreground layer ships at every launcher density', () {
      const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      const canvasSizes = {
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432,
      };
      for (final density in densities) {
        final file = File(
          '$root/android/app/src/main/res/mipmap-$density/'
          'ic_launcher_foreground.png',
        );
        expect(file.existsSync(), isTrue,
            reason: 'missing foreground for $density');
        final dims = pngDimensions(file);
        expect(dims[0], canvasSizes[density], reason: '$density width');
        expect(dims[1], canvasSizes[density], reason: '$density height');
      }
    });

    test('com/example leftover stays deleted', () {
      final dir = Directory(
        '$root/android/app/src/main/kotlin/com/example',
      );
      expect(dir.existsSync(), isFalse,
          reason: 'dead com/example MainActivity resurfaced');
    });
  });

  group('ios Podfile', () {
    test('exists and pins the deployment target used by Runner.xcodeproj',
        () {
      final file = File('$root/ios/Podfile');
      expect(file.existsSync(), isTrue, reason: 'ios/Podfile missing');
      final content = file.readAsStringSync();
      expect(content, contains("platform :ios, '13.0'"));
      expect(content, contains('flutter_additional_ios_build_settings'));
    });
  });

  group('dependency hygiene', () {
    test('removed dead dependencies stay out of pubspec.yaml', () {
      final pubspec = File('$root/pubspec.yaml').readAsStringSync();
      for (final dead in ['dio:', 'cached_network_image:', 'flutter_svg:']) {
        expect(
          pubspec.contains(RegExp('^  $dead', multiLine: true)),
          isFalse,
          reason: 'dead dependency $dead reappeared in pubspec.yaml',
        );
      }
    });
  });
}
