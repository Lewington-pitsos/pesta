import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pesta/bot.dart';
import 'package:pesta/task.dart';
import 'package:pesta/conversation.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:sqflite/sqflite.dart';

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

class FakeDatabase extends Fake implements Database {
  @override
  Future<int> update(String table, Map<String, Object?> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) {
    // TODO: implement update
    return Future(() => 1);
  }
}

void main() {
  late Task task;
  late Task twoTimeTask;
  late Task quorumTask;
  late List<Conversation> conversations;
  late List<Conversation> twoTimeTaskConversations;
  late List<Conversation> quorumTaskConversations;
  late FakeDatabase db;

  group("Conversation Loop", () {
    setUpAll(() {
      db = FakeDatabase();
    });

    setUp(() {
      final jacob =
          PhoneContact("Jacob Sacher", PhoneNumber("04 1234 1678", "mobile"));
      final wendy =
          PhoneContact("wendy Woo", PhoneNumber("99 9999 9999", "mobile"));
      final millie = PhoneContact(
          "Millie Barren-Cohen", PhoneNumber("04 8888 8888", "mobile"));

      task = Task(
          id: 0,
          contacts: [jacob, wendy],
          taskType: TaskType.catchUp,
          activity: "dinner",
          times: [
            DateTimeRange(
                start: DateTime.fromMillisecondsSinceEpoch(1671925246654),
                end: DateTime.fromMillisecondsSinceEpoch(1671933376654))
          ],
          deadline: DateTime.now().add(Duration(milliseconds: 50)));
      conversations = task.makeConversations("bob");

      twoTimeTask = Task(
          id: 0,
          contacts: [jacob, wendy],
          taskType: TaskType.catchUp,
          activity: "dinner",
          times: [
            DateTimeRange(
                start: DateTime(2020, 1, 1, 12, 0),
                end: DateTime(2020, 1, 1, 13, 0)),
            DateTimeRange(
                start: DateTime(2020, 1, 1, 13, 0),
                end: DateTime(2020, 1, 1, 14, 0)),
          ],
          deadline: DateTime.now().add(Duration(milliseconds: 50)));
      twoTimeTaskConversations = twoTimeTask.makeConversations("Bob");

      quorumTask = Task(
          id: 0,
          contacts: [jacob, wendy, millie],
          taskType: TaskType.catchUp,
          activity: "dinner",
          times: [
            DateTimeRange(
                start: DateTime(2020, 1, 1, 12, 0),
                end: DateTime(2020, 1, 1, 13, 0)),
            DateTimeRange(
                start: DateTime(2020, 1, 1, 13, 0),
                end: DateTime(2020, 1, 1, 14, 0)),
          ],
          deadline: DateTime.now().add(Duration(milliseconds: 50)),
          quorum: 3);
      quorumTaskConversations = quorumTask.makeConversations("Paul");
    });

    test("when quorum is 2, second time succeeds", () async {
      final outcome = await conversationLoop(
          db,
          twoTimeTask,
          twoTimeTaskConversations,
          textFn,
          notiFn,
          makeSmsQueryFn(messageBatches: {
            "+61412341678": [
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
          interval: Duration(milliseconds: 5));
      expect(outcome, true);
    });

    test("when quorum is 3, one affirms is not enough", () async {
      final outcome = await conversationLoop(
          db,
          quorumTask,
          quorumTaskConversations,
          textFn,
          notiFn,
          makeSmsQueryFn(messageBatches: {
            "+61412341678": [
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
          interval: Duration(milliseconds: 5));
      expect(outcome, false);
    });

    test("when quorum is 3, two affirms at different times fail", () async {
      final outcome = await conversationLoop(
          db,
          quorumTask,
          quorumTaskConversations,
          textFn,
          notiFn,
          makeSmsQueryFn(messageBatches: {
            "+61412341678": [
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
            ],
            "+61488888888": [
              [],
              [],
              [],
              [
                SmsMessage.fromJson({
                  "address": "+61488888888",
                  "body": "A",
                  "read": 1,
                  "kind": SmsMessageKind.sent,
                  "date": DateTime.now().millisecondsSinceEpoch,
                  "date_sent": DateTime.now().millisecondsSinceEpoch,
                })
              ]
            ]
          }),
          interval: Duration(milliseconds: 5));
      expect(outcome, false);
    });

    test("when quorum is 3, two affirms at the same time succeeds", () async {
      final outcome = await conversationLoop(
          db,
          quorumTask,
          quorumTaskConversations,
          textFn,
          notiFn,
          makeSmsQueryFn(messageBatches: {
            "+61412341678": [
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
            ],
            "+61488888888": [
              [],
              [],
              [],
              [
                SmsMessage.fromJson({
                  "address": "+61488888888",
                  "body": "B",
                  "read": 1,
                  "kind": SmsMessageKind.sent,
                  "date": DateTime.now().millisecondsSinceEpoch,
                  "date_sent": DateTime.now().millisecondsSinceEpoch,
                })
              ]
            ]
          }),
          interval: Duration(milliseconds: 5));
      expect(outcome, true);
    });

    test("fails for no replies", () async {
      final outcome = await conversationLoop(
          db, task, conversations, textFn, notiFn, makeSmsQueryFn(),
          interval: null);
      expect(outcome, false);
    });

    test("succeeds for a single positive reply", () async {
      final outcome = await conversationLoop(
          db,
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

    test("fails for for a single negative reply", () async {
      final outcome = await conversationLoop(
          db,
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
