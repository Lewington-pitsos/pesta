import 'dart:async' show Future;
import 'dart:convert' show json;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pesta/task.dart';
import 'package:background_sms/background_sms.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:pesta/task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'notification.dart';

const databaseName = "taskdb6.db";
const defaultName = "Louka";

class Secret {
  final String SecretKey;
  Secret({this.SecretKey = ""});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(SecretKey: jsonMap["SecretKey"]);
  }

  @override
  String toString() {
    return 'Secret{id: $SecretKey}';
  }
}

void holdConversations() {
  Workmanager().executeTask((taskName, inputData) async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    print("about to notify user");
    await Noti.initialize(notificationsPlugin);

    print("beginning task: $taskName");
    print("this is the inputData $inputData");

    final taskId = inputData!["taskId"];
    final database = await openDatabase(
      join(await getDatabasesPath(), 'taskdb6.db'),
      version: 2,
    );

    final task = await loadTask(taskId, database);

    print("task loaded, $task");

    if (task == null) {
      await Noti.showBigTextNotification(
          title: "Task Failed",
          body:
              "could not find task $taskName, id $taskId in the queue, aborting",
          fln: notificationsPlugin);
      return false;
    }

    final List<Conversation> conversations = task.contacts
        .map((c) => Conversation(
            defaultName,
            c.fullName!.split(" ")[0],
            c.phoneNumber!.number!,
            task.activity,
            task.location,
            task.times[0]))
        .toList();

    print("these are the conversations: $conversations");
    for (var c in conversations) {
      await sendText(kickoff(c, DateTime.now()), c.number);
    }

    List<Conversation> activeConversations = conversations;
    var success = false;

    print("kickoff messages sent");

    while (activeConversations.isNotEmpty &&
        DateTime.now().isBefore(task.deadline)) {
      print("checking ${activeConversations.length} conversations}");
      await updateConversations(activeConversations);
      for (var c in activeConversations.where((c) => c.newResponse)) {
        c.newResponse = false;
        final responseType = await getResponseType(c);

        print("got response type $responseType");

        switch (responseType) {
          case ResponseType.affirmative:
            {
              print("affirmative response");
              c.status = TaskStatus.success;

              await Noti.showBigTextNotification(
                  title: "Success",
                  body:
                      "${c.otherName} agreed to ${task.activity}, see your SMS history with ${c.otherName} for details.",
                  fln: notificationsPlugin);
              return true;
            }

          case ResponseType.negative:
            {
              c.status = TaskStatus.failure;

              await sendText(failurePrompt(c), c.number);
              break;
            }

          case ResponseType.unclear:
            {
              final message = clarificationPrompt(c);
              await sendText(message, c.number);
              c.addSentMessage(message);
              break;
            }

          case ResponseType.manualRequest:
            {
              c.status = TaskStatus.failure;

              await sendText(manualRequestResponse(c), c.number);
              await Noti.showBigTextNotification(
                  title: "help...",
                  body:
                      "${c.otherName} wants to speak to you about to ${task.activity}, see your SMS history with ${c.otherName} for details.",
                  fln: notificationsPlugin);

              break;
            }

          default:
            {
              throw Exception(
                  "unknown response type $responseType for conversation $c");
            }
        }
      }

      activeConversations = activeConversations
          .where((c) => c.status == TaskStatus.ongoing)
          .toList();

      print("awaiting ${activeConversations.length} responses}");
      await Future.delayed(const Duration(seconds: 15));
    }

    await Noti.showBigTextNotification(
        title: "No Takers",
        body:
            "Unable to schedule task $taskName, we asked everyone, but nobody said yes",
        fln: notificationsPlugin);

    return false;
  });
}

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

enum ResponseType { affirmative, negative, unclear, manualRequest }

Future<ResponseType> getResponseType(Conversation c) async {
  print("this is the conversation: ${c.text}");

  final lastMessage = c.lastMessage.toLowerCase().trim();

  if (lastMessage == 'a') {
    return ResponseType.affirmative;
  } else if (lastMessage == 'b') {
    return ResponseType.negative;
  } else if (lastMessage == 'c') {
    return ResponseType.manualRequest;
  } else {
    return ResponseType.unclear;
  }
}

Future updateConversations(List<Conversation> conversations) async {
  SmsQuery query = SmsQuery();

  for (var c in conversations) {
    final List<SmsMessage> messages =
        await query.querySms(address: c.number, kinds: [SmsQueryKind.inbox]);

    for (var msg in messages) {
      if (msg.dateSent != null &&
          msg.dateSent!
              .isAfter(c.startTime.subtract(const Duration(seconds: 1))) &&
          !c.contains(msg)) {
        print("adding message: ${msg.body}, ${msg.id}, ${msg.kind}");
        c.addMessage(msg);
        c.newResponse = true;
      }
    }
  }
}

Future<bool> sendText(String text, String number) async {
  var allowedErrors = 5;
  var formattedNumber = number.replaceAll(" ", "");
  print('about to send sms $text to $formattedNumber');

  while (true) {
    final result = await BackgroundSms.sendMessage(
        phoneNumber: formattedNumber, message: text.split('\n')[0]);
    if (result == SmsStatus.sent) {
      print("sent sms");
      return true;
    } else {
      print("failed to send sms");
      if (allowedErrors > 0) {
        allowedErrors--;
        await Future.delayed(const Duration(seconds: 1));
      } else {
        return false;
      }
    }
  }
}

String failurePrompt(Conversation c) {
  return """Ok... ${c.selfName} might be very sad but I understand...""";
}

String clarificationPrompt(Conversation c) {
  return """I couldn't understand your last message. I'm just a simple bot, I need one of these (single letter) responses:
  A - Yes, let's do it!
  B - No, I'm busy
  C - Go away! I want to talk to ${c.selfName}
  """;
}

String humanReadable(DateTimeRange time) {
  var suffix = "th";
  if (time.start.day == 1) {
    suffix = "st";
  } else if (time.start.day == 2) {
    suffix = "nd";
  } else if (time.start.day == 3) {
    suffix = "rd";
  }

  return "between ${time.start.hour} and ${time.end.hour} on the the ${time.start.day}$suffix";
}

String manualRequestResponse(Conversation c) {
  return "That's ok, I don't have feelings to hurt. I'll let ${c.selfName} know";
}

String kickoff(Conversation c, DateTime time) {
  return """Hi, ${c.otherName} I'm a bot. ${c.selfName} sent me to ask if you want to do ${c.activity} at ${c.location} ${humanReadable(c.time)}. I can only understand these single letter responses:
  A - Yes!
  B - No, I'm busy or something
  C - Go away! I want to talk to ${c.selfName}
  """;
}
