import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

import 'package:pesta/conversation.dart';

void main() {
  late Conversation c1;
  late Conversation c2;

  setUp(() {
    c1 = Conversation("Bob", "Alice", "+612378213", "dinner", "the pub", [
      DateTimeRange(
          start: DateTime(2020, 1, 1, 12, 0), end: DateTime(2020, 1, 1, 13, 0)),
      DateTimeRange(
          start: DateTime(2020, 1, 1, 13, 0), end: DateTime(2020, 1, 1, 14, 0)),
      DateTimeRange(
          start: DateTime(2020, 1, 1, 14, 0), end: DateTime(2020, 1, 1, 15, 0)),
    ]);
    c2 = Conversation("Bob", "Alice", "+612378213", "dinner", "the pub", [
      DateTimeRange(
          start: DateTime(2020, 1, 1, 12, 0), end: DateTime(2020, 1, 1, 13, 0)),
    ]);
  });

  group("Response Parsing", () {
    test("correctly reads negatives", () {
      expect(c2.availableTimes.length, 0);

      c2.addMessage(SmsMessage.fromJson({
        "address": "+612378213",
        "body": "b",
        "read": 1,
        "kind": SmsMessageKind.sent,
        "date": DateTime.now().millisecondsSinceEpoch,
        "date_sent": DateTime.now().millisecondsSinceEpoch,
      }));

      expect(c2.availableTimes.length, 0);
      expect(c2.nextResponse, ResponseType.negative);
    });
  });

  group("Multiple Times", () {
    test("only adds each time once", () {
      expect(c1.availableTimes.length, 0);

      c1.addMessage(SmsMessage.fromJson({
        "address": "+612378213",
        "body": "A",
        "read": 1,
        "kind": SmsMessageKind.sent,
        "date": DateTime.now().millisecondsSinceEpoch,
        "date_sent": DateTime.now().millisecondsSinceEpoch,
      }));

      expect(c1.availableTimes.length, 1);

      c1.addMessage(SmsMessage.fromJson({
        "address": "+612378213",
        "body": "A",
        "read": 1,
        "kind": SmsMessageKind.sent,
        "date": DateTime.now().millisecondsSinceEpoch,
        "date_sent": DateTime.now().millisecondsSinceEpoch,
      }));

      expect(c1.availableTimes.length, 1);
    });
    test("can add multiple times", () {
      expect(c1.availableTimes.length, 0);

      c1.addMessage(SmsMessage.fromJson({
        "address": "+612378213",
        "body": "A",
        "read": 1,
        "kind": SmsMessageKind.sent,
        "date": DateTime.now().millisecondsSinceEpoch,
        "date_sent": DateTime.now().millisecondsSinceEpoch,
      }));

      expect(c1.availableTimes.length, 1);

      c1.addMessage(SmsMessage.fromJson({
        "address": "+612378213",
        "body": "B",
        "read": 1,
        "kind": SmsMessageKind.sent,
        "date": DateTime.now().millisecondsSinceEpoch,
        "date_sent": DateTime.now().millisecondsSinceEpoch,
      }));

      expect(c1.availableTimes.length, 2);
    });
  });
}
