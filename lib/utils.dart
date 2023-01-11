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

    print("about to notify");
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
      await sendText(kickoffPrompt(c, DateTime.now()), c.number);
    }

    List<Conversation> activeConversations = conversations;
    var success = false;

    print("kickoff messages sent");

    while (activeConversations.isNotEmpty &&
        DateTime.now().isBefore(task.deadline)) {
      print("checking ${activeConversations.length} conversations}");
      await updateConversations(activeConversations);
      for (var c in activeConversations.where((c) => c.newMessage)) {
        c.newMessage = false;
        final responseType = await getResponseType(c);

        print("got response type $responseType");

        if (responseType == ResponseType.affirmative) {
          print("affirmative response");
          c.status = TaskStatus.success;

          await notifyUserOfSuccess(c);

          await Noti.showBigTextNotification(
              title: "Success",
              body:
                  "${c.otherName} agreed to ${task.activity}, see your SMS history with ${c.otherName} for more details.",
              fln: notificationsPlugin);
          return true;
        } else if (responseType == ResponseType.negative) {
          c.status = TaskStatus.failure;

          await sendText(failurePrompt(c), c.number);
        } else if (responseType == ResponseType.unclear) {
          // we need further clarification
          final message = clarificationPrompt(c);
          await sendText(message, c.number);
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
            "Unable to schedule task $taskName, we asked everyone, but nobody was free",
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
  bool newMessage = false;
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

enum ResponseType {
  affirmative,
  negative,
  unclear,
}

Future notifyUserOfSuccess(Conversation c) async {
  return Future.delayed(const Duration(milliseconds: 200));
}

Future<ResponseType> getResponseType(Conversation c) async {
  print("this is the conversation: ${c.text}");

  if (c.text.contains('(a)')) {
    return ResponseType.affirmative;
  } else if (c.text.contains('(b)')) {
    return ResponseType.unclear;
  } else {
    return ResponseType.negative;
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
        c.newMessage = true;
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

const tonePrompt = "Use colloquial language. Don't use unnecessary words.";

String statusCheckPrompt(Conversation c) {
  return """Below is an informal sms conversation. Which of the following options describes ${c.otherName}'s attitude, give the most weight to ${c.otherName}'s later responses.

(a) ${c.otherName} is available for ${c.activity} at the specified time
(b) It is unclear whether ${c.otherName} is free for at the specified time
(c) ${c.otherName} is not available for ${c.activity} at the specified time

START CONVERSATION -----

${c.text}

END CONVERSATION -----""";
}

String failurePrompt(Conversation c) {
  return """${c.selfName} was trying to organize to see ${c.otherName} for ${c.activity}. Below is their conversation so far.
  
START CONVERSATION -----

${c.text}

END CONVERSATION -----

${c.selfName} understands that ${c.otherName} is not available this is fine. You are now ${c.selfName}. $tonePrompt.
  
${c.selfName}: """;
}

String clarificationPrompt(Conversation c) {
  return """Below is an informal sms conversation.
  
START CONVERSATION -----

${c.text}

END CONVERSATION -----

${c.selfName} mainly just wants to know if ${c.otherName} wants to come to ${c.activity} at some time between ${c.time.start} and ${c.time.end}. You are now ${c.selfName}. Use colloquial language.

${c.selfName}:""";
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

String kickoffPrompt(Conversation c, DateTime time) {
  return """${c.selfName} wants to meet their ${c.otherName} for ${c.activity} starting at some time between ${c.time.start} and ${c.time.end}, today is $time. ${c.selfName} does not know if their friend is free. ${c.selfName} is about to send an SMS. You're now ${c.selfName}. $tonePrompt

${c.selfName}:""";
}
