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

class Task {
  String taskType;
  int quorum;
  String activity;
  List<DateTimeRange> times;
  String location;
  int neediness;
  String status;

  Task(
      {required List<PhoneContact> contacts,
      required this.taskType,
      required this.activity,
      required this.times,
      this.location = '',
      DateTime? deadline = null,
      this.neediness = 0,
      this.quorum = 2,
      this.status = 'initialization'}) {
    this.contacts = contacts
        .map((c) => PhoneContact(
            c.fullName,
            PhoneNumber(
                formatNumber(c.phoneNumber!.number!), c.phoneNumber?.label)))
        .toList();

    this.deadline = (deadline != null) ? deadline : times[0].start;
  }

  late final List<PhoneContact> contacts;
  late final DateTime deadline;
  @override
  String toString() {
    return 'Task{type: $taskType, activity: $activity, contacts: $contacts times: $times, location: $location, deadline: $deadline, neediness: $neediness, status: $status}';
  }

  Map<String, dynamic> toMap() {
    return {
      'taskType': taskType,
      'activity': activity,
      'location': location,
      'deadline': deadline.millisecondsSinceEpoch,
      'neediness': neediness,
      'quorum': quorum,
      'status': status
    };
  }

  List<Conversation> makeConversations() {
    return contacts
        .map((c) => Conversation("Louka", c.fullName!.split(" ")[0],
            c.phoneNumber!.number!, activity, location, times))
        .toList();
  }
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
      contacts: contacts,
      taskType: taskMaps[0]['taskType'],
      activity: taskMaps[0]['activity'],
      times: times,
      location: taskMaps[0]['location'],
      deadline: DateTime.fromMillisecondsSinceEpoch(taskMaps[0]['deadline']),
      neediness: taskMaps[0]['neediness'],
      quorum: taskMaps[0]['quorum'],
      status: taskMaps[0]['status']);
}

deleteTask(int taskId, Database db) async {
  await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  await db.delete('contacts', where: 'taskId = ?', whereArgs: [taskId]);
  await db.delete('times', where: 'taskId = ?', whereArgs: [taskId]);
}
