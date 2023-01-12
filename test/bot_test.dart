import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pesta/bot.dart';
import 'package:pesta/task.dart';
import 'package:pesta/conversation.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

Future<bool> textFn(String message, String number) async {
  return Future<bool>(() => true);
}

Future<bool> notiFn(String title, String body) async {
  return Future<bool>(() => true);
}

Future<List<SmsMessage>> Function({String? address, List<SmsQueryKind> kinds})
    makeSmsQueryFn(
        {Map<String, List<List<SmsMessage>>> messageBatches = const {}}) {
  final counts = Map<String, int>();

  messageBatches.forEach((key, value) => {counts[key] = 0});

  return (
      {String? address,
      List<SmsQueryKind> kinds = const [SmsQueryKind.inbox]}) async {
    if (address == null) {
      return Future<List<SmsMessage>>(() => <SmsMessage>[]);
    }
    final idx = counts[address];
    if (idx != null) {
      counts[address] = idx + 1;
    }

    if (idx != null && idx >= 0 && idx < messageBatches[address]!.length) {
      return Future<List<SmsMessage>>(() => messageBatches[address]![idx]);
    }

    return Future<List<SmsMessage>>(() => <SmsMessage>[]);
  };
}

void main() {
  late Task task;
  late List<Conversation> conversations;

  group("Conversation Loop", () {
    setUp(() {
      final jacob =
          PhoneContact("Jacob Sacher", PhoneNumber("04 1234 1678", "mobile"));
      final wendy =
          PhoneContact("wendy Woo", PhoneNumber("99 9999 9999", "mobile"));

      task = Task(
          contacts: [jacob, wendy],
          taskType: "invitation",
          activity: "dinner",
          times: [
            DateTimeRange(
                start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
                end: DateTime.fromMillisecondsSinceEpoch(1671933376654))
          ],
          deadline: DateTime.now().add(Duration(milliseconds: 200)));
      conversations = task.contacts
          .map((c) => Conversation(defaultName, c.fullName!.split(" ")[0],
              c.phoneNumber!.number!, task.activity, task.location, task.times))
          .toList();
    });

    test("fails for no replies", () async {
      final outcome = await conversationLoop(
          task, conversations, textFn, notiFn, makeSmsQueryFn(),
          interval: null);
      expect(outcome, false);
    });

    test("succeeds for a single positive reply", () async {
      final outcome = await conversationLoop(
          task,
          conversations,
          textFn,
          notiFn,
          makeSmsQueryFn(messageBatches: {
            "+61412341678": [
              [],
              [],
              [
                SmsMessage.fromJson({
                  "address": "+61412341678",
                  "body": "A",
                  "read": 1,
                  "kind": SmsMessageKind.sent,
                  "date": DateTime.now().millisecondsSinceEpoch,
                  "date_sent": DateTime.now().millisecondsSinceEpoch,
                })
              ]
            ]
          }),
          interval: null);
      expect(outcome, true);
    });
  });

  test("fails for for a single negative reply", () async {
    final outcome = await conversationLoop(
        task,
        conversations,
        textFn,
        notiFn,
        makeSmsQueryFn(messageBatches: {
          "+61412341678": [
            [],
            [],
            [
              SmsMessage.fromJson({
                "address": "+61412341678",
                "body": "b",
                "read": 1,
                "kind": SmsMessageKind.sent,
                "date": DateTime.now().millisecondsSinceEpoch,
                "date_sent": DateTime.now().millisecondsSinceEpoch,
              })
            ]
          ]
        }),
        interval: null);
    expect(outcome, false);
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
