import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pesta/bot.dart';
import 'package:pesta/task.dart';
import 'package:pesta/conversation.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

void main() {
  group("Conversation Loop", () {
    test("sends kickoffs", () async {
      final jacob =
          PhoneContact("Jacob", PhoneNumber("04 1234 1678", "mobile"));
      final wendy =
          PhoneContact("wendy", PhoneNumber("99 9999 9999", "mobile"));

      final task = Task(
          contacts: [jacob, wendy],
          taskType: "invitation",
          activity: "dinner",
          times: [
            DateTimeRange(
                start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
                end: DateTime.fromMillisecondsSinceEpoch(1671933376654))
          ]);
      final c1 = Conversation(
          'Paul', jacob.fullName!, jacob.phoneNumber!.number!, "dinner", "", [
        DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
            end: DateTime.fromMillisecondsSinceEpoch(1671925276654))
      ]);

      final c2 = Conversation(
          'Paul', wendy.fullName!, wendy.phoneNumber!.number!, "dinner", "", [
        DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
            end: DateTime.fromMillisecondsSinceEpoch(1671925276654))
      ]);
      final conversations = [c1, c2];

      final textFn = (String message, String number) async {
        return true;
      };
      final notiFn = (String title, String body) async {
        return true;
      };
      final smsQueryFn = (
          {String? address,
          List<SmsQueryKind> kinds = const [SmsQueryKind.inbox]}) async {
        return <SmsMessage>[];
      };

      await conversationLoop(task, conversations, textFn, notiFn, smsQueryFn);
    });
  });
  group("Conversation", () {
    test('create sms', () {
      final c = Conversation('Paul', 'Jacob', "+61342834665", "dinner", "", [
        DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
            end: DateTime.fromMillisecondsSinceEpoch(1671925276654))
      ]);

      c.addSentMessage("howdy cowdy");

      expect(c.messages.length, 1);

      expect(c.text, "Paul: howdy cowdy\n");
    });

    test('sms interaction', () {
      const address = "73487234";
      const paulAddress = "217489237493";
      const activity = 'dinner';
      final c = Conversation('Paul', 'Jacob', address, activity, "", [
        DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
            end: DateTime.fromMillisecondsSinceEpoch(1671925276654))
      ]);
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
