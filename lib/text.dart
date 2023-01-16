import 'package:flutter/material.dart';
import 'package:pesta/conversation.dart';

String monthFormat(DateTime time) {
  return "${time.day}/${time.month}/${time.year} at ${time.hour}:00";
}

String compactFormat(DateTimeRange time) {
  return "${monthFormat(time.start)} - ${monthFormat(time.end)}";
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

String dateOption(DateTimeRange time) {
  var suffix = "th";
  if (time.start.day == 1) {
    suffix = "st";
  } else if (time.start.day == 2) {
    suffix = "nd";
  } else if (time.start.day == 3) {
    suffix = "rd";
  }

  return "${time.start.hour}00-${time.end.hour}00 on the ${time.start.day}$suffix";
}

String failureSMS(Conversation c) {
  return """Okey dokey I'll let ${c.selfFirstName} know""";
}

String responseOptions(Conversation c) {
  var options = "";
  for (var i = 0; i < c.times.length; i++) {
    options += "${alphabet[i]} - ${dateOption(c.times[i])}\n";
  }
  options += "${alphabet[c.times.length]} - I'm not free\n";
  options +=
      "${alphabet[c.times.length + 1]} - I want to talk to ${c.selfFirstName}\n";

  options += "done - i have entered all my times";

  return options;
}

String clarificationSMS(Conversation c) {
  return """I couldn't understand that. I'm just a simple bot. I still need to know what times you can do:
${responseOptions(c)}""";
}

String manualRequestSMS(Conversation c) {
  return "That's ok, I don't have feelings to hurt. I'll let ${c.selfFirstName} know";
}

String groupSuccessSMS(List<Conversation> conversations,
    DateTimeRange chosenTime, Conversation recipientConversation) {
  var sms = "Great news: ${recipientConversation.selfFirstName}, ";

  sms += conversations
      .where((c) => c != recipientConversation)
      .map((c) => c.otherFirstName)
      .toList()
      .join((", "));

  sms +=
      " and you are all doing ${recipientConversation.activity} starting at ${monthFormat(chosenTime.start)}!\nIf something changes please let everyone else know!";

  return sms;
}

String successSMS(Conversation c) {
  return "Cool!. I'll add that availability to the database.";
}

String formattedNames(List<String> names) {
  if (names.length == 1) {
    return names.first;
  }

  return "${names.sublist(0, names.length - 1).join(", ")} and ${names.last}";
}

String kickoffSMS(Conversation c, DateTime time, List<String> allContacts) {
  final otherContacts = allContacts
      .where((name) => name != c.otherName)
      .map((n) => firstNameOnly(n))
      .toList();
  return """Hi, ${c.otherFirstName} I'm a bot. ${c.selfFirstName} sent me to ask if you want to do ${c.activity}, ${formattedNames(otherContacts)} ${otherContacts.length == 1 ? 'was' : 'were'} also invited. What times are you available? I can only understand these (single letter) responses:
${responseOptions(c)}""";
}

String notificationSMS(Conversation c) {
  return c.activity;
}
