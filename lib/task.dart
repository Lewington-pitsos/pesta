import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';

class Task {
  List contacts;
  String eventType;
  String event;
  List times;
  String location;
  String customMessage;
  int responseTimeMins;
  DateTime deadline;
  int maxPolls;
  int neediness;
  bool alternateSuggestion;
  String status;

  Task(
      this.contacts,
      this.eventType,
      this.event,
      this.times,
      this.location,
      this.customMessage,
      this.responseTimeMins,
      this.deadline,
      this.maxPolls,
      this.neediness,
      this.alternateSuggestion,
      this.status);
}
