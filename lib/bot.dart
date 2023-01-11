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
import 'package:pesta/conversation.dart';
import 'package:pesta/text.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'notification.dart';

const databaseName = "taskdb6.db";
const defaultName = "Louka";

sendResponses(Task task, List<Conversation> conversations,
    FlutterLocalNotificationsPlugin notificationsPlugin) async {
  for (var c
      in conversations.where((c) => c.nextResponse != ResponseType.none)) {
    c.setResponded();
    final responseType = c.nextResponse;

    switch (responseType) {
      case ResponseType.affirmative:
        {
          print("affirmative response");
          await sendText(successSMS(c), c.number);
          break;
        }

      case ResponseType.negative:
        {
          await sendText(failureSMS(c), c.number);
          break;
        }

      case ResponseType.unclear:
        {
          final message = clarificationSMS(c);
          await sendText(message, c.number);
          c.addSentMessage(message);
          break;
        }

      case ResponseType.manualRequest:
        {
          await sendText(manualRequestSMS(c), c.number);
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
}

Future<bool> checkStatus(Task task, List<Conversation> conversations,
    FlutterLocalNotificationsPlugin notificationsPlugin) async {
  for (var c in conversations) {
    if (c.isAvailable) {
      await Noti.showBigTextNotification(
          title: "Success",
          body:
              "${c.otherName} agreed to ${task.activity}, see your SMS history with ${c.otherName} for details.",
          fln: notificationsPlugin);
      return true;
    }
  }

  return false;
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
        .map((c) => Conversation(defaultName, c.fullName!.split(" ")[0],
            c.phoneNumber!.number!, task.activity, task.location, task.times))
        .toList();

    print("these are the conversations: $conversations");
    for (var c in conversations) {
      await sendText(kickoffSMS(c, DateTime.now()), c.number);
    }

    List<Conversation> activeConversations = conversations;
    print("kickoff messages sent");

    while (activeConversations.isNotEmpty &&
        DateTime.now().isBefore(task.deadline)) {
      print("checking ${activeConversations.length} conversations}");
      await updateConversations(activeConversations);
      await sendResponses(task, activeConversations, notificationsPlugin);
      final success =
          await checkStatus(task, conversations, notificationsPlugin);

      if (success) {
        return true;
      }

      activeConversations = activeConversations
          .where((c) => c.availability != Availability.finalized)
          .toList();

      print("awaiting ${activeConversations.length} responses}");
      await Future.delayed(const Duration(seconds: 60 * 5));
    }

    await Noti.showBigTextNotification(
        title: "No takers",
        body:
            "Unable to schedule task $taskName, we asked everyone, but nobody said yes",
        fln: notificationsPlugin);

    return false;
  });
}

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
