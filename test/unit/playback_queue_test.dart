import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalpkrut_beats/domain/models/track.dart';
import 'package:kalpkrut_beats/domain/playback/playback_queue.dart';

Track t(String id) =>
    Track(id: id, providerId: 'demo', providerTrackId: id, title: 'Track $id');

void main() {
  group('PlaybackQueue', () {
    test('setQueue + current', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a'), t('b'), t('c')]);
      expect(q.current!.id, 'a');
      expect(q.length, 3);
    });

    test('next advances and stops at end with repeat off', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a'), t('b')]);
      expect(q.next()!.id, 'b');
      expect(q.next(), isNull);
    });

    test('repeat all wraps', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a'), t('b')]);
      q.repeat = RepeatMode.all;
      q.next();
      expect(q.next()!.id, 'a');
    });

    test('repeat one stays on current', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a'), t('b')]);
      q.repeat = RepeatMode.one;
      expect(q.next()!.id, 'a');
    });

    test('previous goes back', () {
      final q = PlaybackQueue()
        ..setQueue(<Track>[t('a'), t('b'), t('c')], startIndex: 2);
      expect(q.previous()!.id, 'b');
    });

    test('playNext inserts after current', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a'), t('b')]);
      q.playNext(t('x'));
      expect(q.tracks[1].id, 'x');
      expect(q.next()!.id, 'x');
    });

    test('removeAt keeps current valid', () {
      final q = PlaybackQueue()
        ..setQueue(<Track>[t('a'), t('b'), t('c')], startIndex: 1);
      final removedCurrent = q.removeAt(1);
      expect(removedCurrent, isTrue);
      expect(q.length, 2);
      expect(q.current, isNotNull);
    });

    test(
      'shuffle produces a full permutation and next never null with repeat off',
      () {
        final q = PlaybackQueue(random: Random(1))
          ..setQueue(<Track>[t('a'), t('b'), t('c'), t('d')]);
        q.setShuffle(true);
        final Set<String> seen = <String>{};
        Track? cur = q.current;
        while (cur != null) {
          seen.add(cur.id);
          cur = q.next();
        }
        expect(seen.length, 4);
      },
    );

    test('queue dedupes on appendAll', () {
      final q = PlaybackQueue()..setQueue(<Track>[t('a')]);
      q.appendAll(<Track>[t('a'), t('b')]);
      expect(q.length, 2);
    });
  });
}
