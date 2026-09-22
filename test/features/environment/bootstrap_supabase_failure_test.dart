import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/app/bootstrap/app_bootstrap.dart';
import 'package:vaanix_app/core/constants/app_constants.dart';

void main() {
  test('configured Supabase initialization failure aborts bootstrap', () async {
    dotenv.testLoad(mergeWith: <String, String>{
      AppConstants.supabaseUrlKey: 'https://project.supabase.co',
      AppConstants.supabaseAnonKeyKey: 'test-anon-key',
    });

    await expectLater(
      bootstrap(
        supabaseInitializer: ({required url, required anonKey}) async {
          throw StateError('simulated Supabase initialization failure');
        },
      ),
      throwsA(isA<StateError>()),
    );
  });
}
