import 'dart:async' show Future;
import 'dart:convert' show json;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:pesta/sms.dart';
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

sendResponses(
    Task task,
    List<Conversation> conversations,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn) async {
  for (var c
      in conversations.where((c) => c.nextResponse != ResponseType.none)) {
    final responseType = c.nextResponse;
    c.setResponded();

    print("response type $responseType");

    switch (responseType) {
      case ResponseType.affirmative:
        {
          print("affirmative response");
          await textFn(successSMS(c), c.number);
          break;
        }

      case ResponseType.negative:
        {
          print("negative response");
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
              "${c.otherFirstName} wants to speak to you about to ${task.activity}, see your SMS history with ${c.otherFirstName} for details.");

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

Future<Map<DateTimeRange, List<Conversation>>> checkStatus(
    Task task, List<Conversation> conversations) async {
  final availableGuests = Map<DateTimeRange, List<Conversation>>();
  for (var c in conversations) {
    if (c.isAvailable) {
      for (var t in c.availableTimes) {
        availableGuests[t] = availableGuests[t] ?? [];
        availableGuests[t]!.add(c);
      }
    }
  }

  final quarumMeetingTimes = Map<DateTimeRange, List<Conversation>>();

  for (var t in availableGuests.keys) {
    final guests = availableGuests[t]!;
    if (guests.length >= task.quorum - 1) {
      quarumMeetingTimes[t] = guests;
    }
  }

  return quarumMeetingTimes;
}

Future<bool> sendNotifications(
    Database db,
    Task task,
    List<Conversation> conversations,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn) async {
  print("about to send ${conversations.length} notifications");

  if (task.status.index < TaskStatus.kickedOff.index) {
    for (var c in conversations) {
      try {
        await textFn(notificationSMS(c), c.number);
      } catch (e) {
        notiFn("Error", "Failed to send notification: $e for conversation $c");
        await updateTaskStatus(task, db, TaskStatus.failed);
        return false;
      }
    }
    await updateTaskStatus(task, db, TaskStatus.kickedOff);
  }

  if (task.status.index < TaskStatus.completed.index) {
    notiFn("Success",
        "${conversations.map((c) => c.otherFirstName).join(", ")} have all been notified.");

    await updateTaskStatus(task, db, TaskStatus.completed);
    return true;
  }
  return true;
}

Future<bool> conversationLoop(
    Database db,
    Task task,
    List<Conversation> conversations,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn,
    Future<List<SmsMessage>> Function(
            {String? address, List<SmsQueryKind> kinds})
        smsQueryFn,
    {Duration? interval = const Duration(seconds: 60 * 5)}) async {
  if (task.status.index < TaskStatus.kickedOff.index) {
    for (var c in conversations) {
      await textFn(kickoffSMS(c, DateTime.now(), task.allContacts()), c.number);
    }
    await updateTaskStatus(task, db, TaskStatus.kickedOff);
  }

  List<Conversation> activeConversations = conversations;
  print("kickoff messages sent");

  if (task.status.index < TaskStatus.postConversation.index) {
    while (activeConversations.isNotEmpty &&
        DateTime.now().isBefore(task.deadline)) {
      print("checking ${activeConversations.length} conversations}");
      await updateConversations(activeConversations, smsQueryFn);
      await sendResponses(task, activeConversations, textFn, notiFn);
      final quarumMeetingTimes = await checkStatus(task, conversations);
      print("quarum meeting times: $quarumMeetingTimes");

      if (quarumMeetingTimes.isNotEmpty) {
        final success =
            await notifySuccess(task, textFn, notiFn, quarumMeetingTimes);
        if (success) {
          updateTaskStatus(task, db, TaskStatus.completed);
        }

        return success;
      }

      activeConversations = activeConversations
          .where((c) => c.availability == Availability.undetermined)
          .toList();

      print("awaiting ${activeConversations.length} responses}");
      if (interval != null) {
        await Future.delayed(interval);
      }
    }
    await updateTaskStatus(task, db, TaskStatus.postConversation);
  }

  await notiFn("No takers",
      "Can't schedule task ${task.activity}, we asked everyone, but nobody said yes");
  await updateTaskStatus(task, db, TaskStatus.failed);

  return false;
}

Future<bool> notifySuccess(
    Task task,
    Future<bool> Function(String, String) textFn,
    Future<dynamic> Function(String, String) notiFn,
    Map<DateTimeRange, List<Conversation>> quarumMeetingTimes) async {
  final meetingTime = quarumMeetingTimes.keys.first;
  final guests = quarumMeetingTimes[meetingTime]!;

  for (var c in guests) {
    await textFn(groupSuccessSMS(guests, meetingTime, c), c.number);
  }

  await notiFn("Success",
      "${guests.map((g) => g.otherFirstName).join(", ")} have all agreed to attend ${task.activity}, at ${meetingTime.start}. Everyone has been sent an SMS notification confirming everyone else's attendance. See SMS history with each guest for more details.");

  return true;
}

void holdConversations() {
  Workmanager().executeTask((taskName, inputData) async {
    print("beginning task: $taskName");
    print("this is the inputData $inputData");

    final taskId = inputData!["taskId"];
    final database = await openDatabase(
      join(await getDatabasesPath(), databaseName),
      version: 2,
    );

    final task = await loadTask(taskId, database);

    print("task loaded, $task");

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await Noti.initialize(notificationsPlugin);
    if (task == null) {
      await Noti.showBigTextNotification(
          title: "Task Failed",
          body:
              "could not find task $taskName, id $taskId in the queue, aborting",
          fln: notificationsPlugin);
      return false;
    }

    if (task.status == TaskStatus.completed) {
      print('task has already been completed, marking as finished $task');
      return true;
    }

    final List<Conversation> conversations = task.makeConversations();
    const textFn = sendText;
    notiFn(String title, String body) => Noti.showBigTextNotification(
        title: title, body: body, fln: notificationsPlugin);
    SmsQuery query = SmsQuery();
    smsQueryFn(
            {String? address,
            List<SmsQueryKind> kinds = const [SmsQueryKind.inbox]}) =>
        query.querySms(address: address, kinds: kinds);
    print("these are the conversations: $conversations");

    switch (task.taskType) {
      case TaskType.notification:
        return await sendNotifications(
            database, task, conversations, textFn, notiFn);
      case TaskType.catchUp:
        return await conversationLoop(
            database, task, conversations, textFn, notiFn, smsQueryFn);
      default:
        print("unknown task type: ${task.taskType}");
        return false;
    }
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

Future<bool> sendText(String textMessage, String number) async {
  print('about to send sms $textMessage to |$number|');

  return sendSms(number, textMessage);
}
