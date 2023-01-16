import 'dart:async';
import 'dart:ffi';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/material.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'package:pesta/conversation.dart';

String formatNumber(String phoneNumber) {
  var formatted = phoneNumber.replaceAll(" ", "");

  if (formatted.startsWith("04")) {
    formatted = formatted.replaceFirst("04", "+614");
  }

  return formatted;
}

enum TaskType { notification, catchUp, groupSession, askToBorrow }

final taskToNameMap = {
  TaskType.notification: 'Notification',
  TaskType.catchUp: 'Catch-Up',
  TaskType.groupSession: 'Group Session',
  TaskType.askToBorrow: 'Ask To Borrow'
};
final nameToTaskMap = taskToNameMap.map((k, v) => MapEntry(v, k));

enum TaskStatus { created, kickedOff, postConversation, completed, failed }

final statusToStringMap = {
  TaskStatus.created: 'Created',
  TaskStatus.kickedOff: 'Kicked Off',
  TaskStatus.postConversation: 'Post Conversation',
  TaskStatus.completed: 'Completed',
  TaskStatus.failed: 'Failed'
};
final stringToStatusMap = statusToStringMap.map((k, v) => MapEntry(v, k));

class Task {
  int id = 0;
  TaskType taskType;
  int quorum;
  String activity;
  List<DateTimeRange> times;
  String location;
  int neediness;
  TaskStatus status;

  Task(
      {required int id,
      required List<PhoneContact> contacts,
      required this.taskType,
      required this.activity,
      required this.times,
      this.location = '',
      DateTime? deadline = null,
      this.neediness = 0,
      this.quorum = 2,
      this.status = TaskStatus.created}) {
    this.contacts = contacts
        .map((c) => PhoneContact(
            c.fullName,
            PhoneNumber(
                formatNumber(c.phoneNumber!.number!), c.phoneNumber?.label)))
        .toList();
    this.deadline = (deadline != null)
        ? deadline
        : (times.length > 0 ? times[0].start : DateTime.now());
  }

  late final List<PhoneContact> contacts;
  late final DateTime deadline;
  @override
  String toString() {
    return 'Task{type: ${taskToNameMap[taskType]}, activity: $activity, contacts: $contacts times: $times, location: $location, deadline: $deadline, neediness: $neediness, status: $status}';
  }

  List<String> allContacts() {
    return contacts.map((c) => c.fullName!).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'taskType': taskToNameMap[taskType],
      'activity': activity,
      'location': location,
      'deadline': deadline.millisecondsSinceEpoch,
      'neediness': neediness,
      'quorum': quorum,
      'status': statusToStringMap[status],
    };
  }

  List<Conversation> makeConversations(String hostName) {
    return contacts
        .map((c) => Conversation(hostName, c.fullName!, c.phoneNumber!.number!,
            activity, location, times))
        .toList();
  }
}

Future<bool> updateTaskStatus(Task task, Database db, TaskStatus status) async {
  task.status = status;
  return await updateTask(task, db);
}

Future<bool> updateTask(Task task, Database db) async {
  int rowsAffected = await db
      .update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  return rowsAffected > 0;
}

Future<int> saveTask(Task task, Database db) async {
  int taskId = await db.insert('tasks', task.toMap());
  for (PhoneContact contact in task.contacts) {
    await db.insert('contacts', {
      'taskId': taskId,
      'fullName': contact.fullName,
      'phoneNumber': contact.phoneNumber?.number ?? '',
      'phoneNumberName': contact.phoneNumber?.label ?? '',
    });
  }
  for (DateTimeRange time in task.times) {
    await db.insert('times', {
      'taskId': taskId,
      'start': time.start.millisecondsSinceEpoch,
      'end': time.end.millisecondsSinceEpoch,
    });
  }

  return taskId;
}

// uses the taskId to load the task from the sqflite database
Future<Task?> loadTask(int taskId, Database db) async {
  List<Map<String, dynamic>> taskMaps = await db.query('tasks',
      columns: [
        'taskType',
        'activity',
        'location',
        'deadline',
        'neediness',
        'status',
        'quorum',
      ],
      where: 'id = ?',
      whereArgs: [taskId]);
  List<Map<String, dynamic>> contactMaps = await db.query('contacts',
      columns: ['fullName', 'phoneNumber'],
      where: 'taskId = ?',
      whereArgs: [taskId]);
  List<Map<String, dynamic>> timeMaps = await db.query('times',
      columns: ['start', 'end'], where: 'taskId = ?', whereArgs: [taskId]);

  if (taskMaps.isEmpty) {
    return null;
  }

  List<PhoneContact> contacts = [];
  for (Map<String, dynamic> contactMap in contactMaps) {
    contacts.add(PhoneContact(contactMap['fullName'],
        PhoneNumber(contactMap['phoneNumber'], contactMap['phoneNumberName'])));
  }

  List<DateTimeRange> times = [];
  for (Map<String, dynamic> timeMap in timeMaps) {
    times.add(DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(timeMap['start']),
        end: DateTime.fromMillisecondsSinceEpoch(timeMap['end'])));
  }

  return Task(
      id: taskId,
      contacts: contacts,
      taskType: nameToTaskMap[taskMaps[0]['taskType']]!,
      activity: taskMaps[0]['activity'],
      times: times,
      location: taskMaps[0]['location'],
      deadline: DateTime.fromMillisecondsSinceEpoch(taskMaps[0]['deadline']),
      neediness: taskMaps[0]['neediness'],
      quorum: taskMaps[0]['quorum'],
      status: stringToStatusMap[taskMaps[0]['status']]!);
}

deleteTask(int taskId, Database db) async {
  await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  await db.delete('contacts', where: 'taskId = ?', whereArgs: [taskId]);
  await db.delete('times', where: 'taskId = ?', whereArgs: [taskId]);
}
