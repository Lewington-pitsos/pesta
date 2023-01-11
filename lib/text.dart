import 'package:flutter/material.dart';
import 'package:pesta/conversation.dart';

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
