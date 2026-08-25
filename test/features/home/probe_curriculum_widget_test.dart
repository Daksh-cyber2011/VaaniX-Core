import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';

class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curriculumProvider);
    return Text(state.when(
      data: (chapters) => 'DATA:${chapters.length}',
      error: (e, _) => 'ERROR:$e',
      loading: () => 'LOADING',
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('curriculum provider loads in a bare widget', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _Probe())),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final text = tester.widget<Text>(find.byType(Text)).data!;
    print('PROBE RESULT: $text');
    expect(text.startsWith('DATA:'), isTrue, reason: 'saw: $text');
  });
}