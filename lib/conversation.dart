import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sql.dart';

enum Availability {
  undetermined,
  partiallyDetermined,
  finalized,
}

enum ResponseType { none, affirmative, negative, unclear, done, manualRequest }

const finalizingResponseTypes = [
  ResponseType.done,
  ResponseType.negative,
  ResponseType.manualRequest
];

class ConversationStatus {
  ResponseType responseType = ResponseType.none;
  Availability availability = Availability.undetermined;
  Set<DateTimeRange> availableTimes = {};
}

class ResponseData {
  final ResponseType type;
  final int index;

  ResponseData(this.type, this.index);
}

const alphabet = "abcdefghijklmnopqrstuvwxyz";

ResponseData getResponseData(int optionCount, String message) {
  print("this is the message: $message");

  final lastMessage = message.toLowerCase().trim();

  if (lastMessage.length == 1) {
    final index = alphabet.indexOf(lastMessage);

    if (index >= 0 && index < optionCount) {
      return ResponseData(ResponseType.affirmative, index);
    } else if (index == optionCount) {
      return ResponseData(ResponseType.negative, -1);
    } else if (index == optionCount + 1) {
      return ResponseData(ResponseType.manualRequest, -1);
    } else if (index == optionCount + 2) {
      return ResponseData(ResponseType.done, -1);
    }
  }

  return ResponseData(ResponseType.unclear, -1);
}

class Conversation {
  String selfName;
  String otherName;
  String activity;
  String location;
  List<DateTimeRange> times;
  DateTime startTime = DateTime.now();
  String number;
  List<SmsMessage> messages = [];

  ResponseType nextResponse = ResponseType.none;
  Availability availability = Availability.undetermined;
  Set<DateTimeRange> availableTimes = {};

  Conversation(this.selfName, this.otherName, this.number, this.activity,
      this.location, this.times);

  bool contains(SmsMessage msg) {
    return messages.any((m) => m.id == msg.id);
  }

  _getNextResponseType(ResponseType newResponseType) {
    switch (nextResponse) {
      case ResponseType.none:
        return newResponseType;
      case ResponseType.affirmative:
        return newResponseType;
      case ResponseType.negative:
        return ResponseType.negative;
      case ResponseType.done:
        return ResponseType.done;
      case ResponseType.manualRequest:
        return ResponseType.manualRequest;
      case ResponseType.unclear:
        return newResponseType;
      default:
        throw Exception("unknown response type ${nextResponse}");
    }
  }

  addMessage(SmsMessage message) {
    final responseData = getResponseData(times.length, message.body ?? "");

    if (responseData.type == ResponseType.affirmative) {
      final time = this.times[responseData.index];
      this.availableTimes.add(time);

      if (this.availability == Availability.undetermined) {
        this.availability = Availability.partiallyDetermined;
      }

      if (this.availableTimes.length == this.times.length) {
        this.availability = Availability.finalized;
      }
    }

    nextResponse = _getNextResponseType(responseData.type);

    if (finalizingResponseTypes.contains(nextResponse)) {
      availability = Availability.finalized;
    }

    messages.add(message);
  }

  setResponded() {
    nextResponse = ResponseType.none;
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

  get isAvailable {
    return availability == Availability.finalized && availableTimes.isNotEmpty;
  }
}
