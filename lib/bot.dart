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

const databaseName = "taskdb7.db";
const defaultName = "Louka";

sendResponses(
    Task task,
    List<Conversation> conversations,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn) async {
  for (var c
      in conversations.where((c) => c.nextResponse != ResponseType.none)) {
    final responseType = c.nextResponse;
    c.setResponded();

    switch (responseType) {
      case ResponseType.affirmative:
        {
          print("affirmative response");
          await textFn(successSMS(c), c.number);
          break;
        }

      case ResponseType.negative:
        {
          await textFn(failureSMS(c), c.number);
          break;
        }

      case ResponseType.unclear:
        {
          final message = clarificationSMS(c);
          await textFn(message, c.number);
          c.addSentMessage(message);
          break;
        }

      case ResponseType.manualRequest:
        {
          await textFn(manualRequestSMS(c), c.number);
          await notiFn("help...",
              "${c.otherName} wants to speak to you about to ${task.activity}, see your SMS history with ${c.otherName} for details.");

          break;
        }

      case ResponseType.none:
        {
          throw Exception(
              "response type $responseType should not be possible: $c");
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
    Future<dynamic> Function(String, String) notiFn) async {
  for (var c in conversations) {
    if (c.isAvailable) {
      await notiFn("Success",
          "${c.otherName} agreed to ${task.activity}, see your SMS history with ${c.otherName} for details.");
      return true;
    }
  }

  return false;
}

Future<bool> conversationLoop(
    Task task,
    List<Conversation> conversations,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn,
    Future<List<SmsMessage>> Function(
            {String? address, List<SmsQueryKind> kinds})
        smsQueryFn,
    {Duration? interval = const Duration(seconds: 60 * 5)}) async {
  for (var c in conversations) {
    await textFn(kickoffSMS(c, DateTime.now()), c.number);
  }

  List<Conversation> activeConversations = conversations;
  print("kickoff messages sent");

  while (activeConversations.isNotEmpty &&
      DateTime.now().isBefore(task.deadline)) {
    print("checking ${activeConversations.length} conversations}");
    await updateConversations(activeConversations, smsQueryFn);
    await sendResponses(task, activeConversations, textFn, notiFn);
    final success = await checkStatus(task, conversations, notiFn);

    if (success) {
      return true;
    }

    activeConversations = activeConversations
        .where((c) => c.availability != Availability.finalized)
        .toList();

    print("awaiting ${activeConversations.length} responses}");
    if (interval != null) {
      await Future.delayed(interval);
    }
  }

  await notiFn("No takers",
      "Can't schedule task ${task.activity}, we asked everyone, but nobody said yes");

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
      join(await getDatabasesPath(), databaseName),
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

    const textFn = sendText;
    notiFn(String title, String body) => Noti.showBigTextNotification(
        title: title, body: body, fln: notificationsPlugin);
    SmsQuery query = SmsQuery();
    smsQueryFn(
            {String? address,
            List<SmsQueryKind> kinds = const [SmsQueryKind.inbox]}) =>
        query.querySms(address: address, kinds: kinds);
    print("these are the conversations: $conversations");

    return await conversationLoop(
        task, conversations, textFn, notiFn, smsQueryFn);
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

Future updateConversations(
    List<Conversation> conversations,
    Future<List<SmsMessage>> Function(
            {String? address, List<SmsQueryKind> kinds})
        smsQueryFn) async {
  for (var c in conversations) {
    print("address ${c.number}");
    final List<SmsMessage> messages =
        await smsQueryFn(address: c.number, kinds: [SmsQueryKind.inbox]);

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
