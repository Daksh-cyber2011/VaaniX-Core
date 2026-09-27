/// Tests for the per-user scoped local storage.
///
/// Pins the contract:
///   * All keyed reads/writes are routed through the active user's
///     namespace; the inner backing storage never sees an unscoped
///     key.
///   * `rebind(otherUser)` switches namespaces — User A's data is no
///     longer reachable.
///   * `wipeUser(userId)` deletes every key owned by that user.
///   * `clear()` removes only keys belonging to the current scope.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/core/storage/scoped_local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('writes are namespaced under the active user', () async {
    final prefs = await SharedPreferences.getInstance();
    final backing = LocalStorageService(prefs);
    final scoped = ScopedLocalStorage(backing, currentUserId: 'A');
    await scoped.setXpTotal(42);
    expect(
      prefs.getKeys().any((k) => k.contains('A') && k.contains('xp')),
      isTrue,
      reason: 'a key matching the user namespace MUST be present',
    );
  });

  test('rebinding to user B makes A\'s data unreachable', () async {
    final prefs = await SharedPreferences.getInstance();
    final backing = LocalStorageService(prefs);
    final scoped = ScopedLocalStorage(backing, currentUserId: 'A');
    await scoped.setXpTotal(42);
    expect(scoped.xpTotal, 42);

    scoped.rebind('B');
    expect(scoped.xpTotal, 0,
        reason: 'after rebind, A\'s xp MUST NOT be visible to B');
  });

  test('wipeUser removes every key for that user', () async {
    final prefs = await SharedPreferences.getInstance();
    final backing = LocalStorageService(prefs);
    final scoped = ScopedLocalStorage(backing, currentUserId: 'A');
    await scoped.setXpTotal(42);
    await scoped.setString('cache-key', '{"k":"v"}');

    await scoped.wipeUser('A');
    expect(scoped.xpTotal, 0);
    expect(scoped.getString('cache-key'), isNull);
  });

  test('clear() only removes the active scope\'s keys', () async {
    final prefs = await SharedPreferences.getInstance();
    final backing = LocalStorageService(prefs);
    final scoped = ScopedLocalStorage(backing, currentUserId: 'A');
    await scoped.setXpTotal(11);

    // Switch to user B and write something.
    scoped.rebind('B');
    await scoped.setXpTotal(22);
    expect(scoped.xpTotal, 22);

    // Now rebind back to A and clear — should NOT touch B's data.
    scoped.rebind('A');
    await scoped.clear();
    expect(scoped.xpTotal, 0);

    scoped.rebind('B');
    expect(scoped.xpTotal, 22,
        reason: 'clearing the A scope MUST NOT affect the B scope');
  });

  test('guest writes are partitioned from user writes', () async {
    final prefs = await SharedPreferences.getInstance();
    final backing = LocalStorageService(prefs);
    final scoped = ScopedLocalStorage(backing, currentUserId: null);
    await scoped.setXpTotal(7);
    expect(scoped.xpTotal, 7);

    scoped.rebind('A');
    expect(scoped.xpTotal, 0);
  });
}
