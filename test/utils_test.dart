import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pesta/utils.dart';

void main() {
  group("Conversation", () {
    test('create sms', () {
      final c = Conversation(
          'Paul',
          'Jacob',
          "+61342834665",
          "dinner",
          "",
          DateTimeRange(
              start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
              end: DateTime.fromMillisecondsSinceEpoch(1671925276654)));

      c.addSentMessage("howdy cowdy");

      expect(c.messages.length, 1);

      expect(c.text, "Paul: howdy cowdy\n");
    });

    test('sms interaction', () {
      const address = "73487234";
      const paulAddress = "217489237493";
      const activity = 'dinner';
      final c = Conversation(
          'Paul',
          'Jacob',
          address,
          activity,
          "",
          DateTimeRange(
              start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
              end: DateTime.fromMillisecondsSinceEpoch(1671925276654)));
      expect(c.text, "");

      const paulMessage1 = "Hey Jacob, let's go to dinner tonight";

      c.addMessage(SmsMessage.fromJson({
        "address": paulAddress,
        "body": paulMessage1,
        "date": 1671925246654,
        "date_sent": 1671925246654,
        "id": 1,
        "read": 1,
        "status": 1,
        "kind": SmsMessageKind.sent,
      }));

      expect(c.text, "Paul: $paulMessage1\n");

      c.addMessage(SmsMessage.fromJson({
        "address": address,
        "body": "Sure, where?",
        "date": 1671925276654,
        "date_sent": 1671925276654,
        "id": 2,
        "read": 1,
        "status": 1,
        "kind": SmsMessageKind.received,
      }));

      expect(c.text, """Paul: $paulMessage1
Jacob: Sure, where?
""");
    });
  });
}
