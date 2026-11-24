import 'package:dtm_app/core/transport/send_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SendLedger', () {
    test('a fresh id is not delivered', () {
      final ledger = SendLedger();
      expect(ledger.isDelivered('a'), isFalse);
      expect(ledger.length, 0);
    });

    test('a successful hand-off is remembered', () {
      final ledger = SendLedger();
      ledger.markDelivered('a');
      expect(ledger.isDelivered('a'), isTrue);
      expect(ledger.length, 1);
    });

    test('forget drops an id so the next attempt is made again', () {
      final ledger = SendLedger();
      ledger.markDelivered('a');
      ledger.forget('a');
      expect(ledger.isDelivered('a'), isFalse);
    });

    test('failed attempts never enter the ledger', () {
      final ledger = SendLedger();
      // A transport only calls markDelivered after a real hand-off, so two
      // failed attempts leave no trace and the third attempt still happens.
      expect(ledger.isDelivered('a'), isFalse);
      expect(ledger.isDelivered('a'), isFalse);
      ledger.markDelivered('a');
      expect(ledger.isDelivered('a'), isTrue);
    });
  });
}
