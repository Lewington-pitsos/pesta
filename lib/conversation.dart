import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter/material.dart';

enum TaskStatus {
  ongoing,
  success,
  failure,
  moot,
}

class Conversation {
  TaskStatus status = TaskStatus.ongoing;
  bool newResponse = false;
  String selfName;
  String otherName;
  String activity;
  String location;
  DateTimeRange time;
  DateTime startTime = DateTime.now();
  String number;
  List<SmsMessage> messages = [];

  Conversation(this.selfName, this.otherName, this.number, this.activity,
      this.location, this.time);

  bool contains(SmsMessage msg) {
    return messages.any((m) => m.id == msg.id);
  }

  addMessage(SmsMessage message) {
    messages.add(message);
  }

  String get lastMessage {
    final recievedMessages =
        messages.where((m) => m.kind == SmsMessageKind.received);

    if (recievedMessages.isEmpty) {
      return "";
    }

    return recievedMessages.last.body ?? "";
  }

  addSentMessage(String message) {
    messages.add(SmsMessage.fromJson({
      "address": number,
      "body": message,
      "read": 1,
      "kind": SmsMessageKind.sent,
      "date": DateTime.now().millisecondsSinceEpoch,
      "date_sent": DateTime.now().millisecondsSinceEpoch,
    }));
  }

  String get text {
    var txt = "";

    for (var message in messages) {
      final name =
          message.kind == SmsMessageKind.received ? otherName : selfName;

      txt += "$name: ${message.body}\n";
    }

    return txt;
  }
}
