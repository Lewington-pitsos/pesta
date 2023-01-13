import 'package:background_sms/background_sms.dart';

List<String> breakUp(String message) {
  final List<String> brokenMessages = [];

  var lastBreak = 0;
  var spaceIndex = -1;
  var newlineIndex = -1;

  for (var i = 0; i < message.length; i++) {
    final char = message[i];
    if (char == ' ') {
      spaceIndex = i;
    } else if (char == "\n") {
      newlineIndex = i;
    }

    if (i - lastBreak == 160) {
      late int breakIndex;
      if (newlineIndex > lastBreak) {
        breakIndex = newlineIndex;
      } else if (spaceIndex > lastBreak) {
        breakIndex = spaceIndex;
      } else {
        breakIndex = i;
      }
      brokenMessages.add(message.substring(lastBreak, breakIndex).trim());
      lastBreak = breakIndex;
      spaceIndex = lastBreak;
      newlineIndex = lastBreak;
    }
  }

  brokenMessages.add(message.substring(lastBreak, message.length).trim());

  return brokenMessages;
}

Future<bool> sendSms(String phoneNumber, String fullMessage) async {
  final messages = breakUp(fullMessage);

  for (final shortMessage in messages) {
    final result = await send160CharSms(phoneNumber, shortMessage);

    if (result == false) {
      return false;
    }
  }

  return true;
}

Future<bool> send160CharSms(String phoneNumber, String message) async {
  var allowedErrors = 5;
  while (true) {
    final result = await BackgroundSms.sendMessage(
        phoneNumber: phoneNumber, message: message);
    if (result == SmsStatus.sent) {
      print("sent sms");
      return true;
    } else {
      print("failed to send sms $result");
      if (allowedErrors > 0) {
        allowedErrors--;
        await Future.delayed(const Duration(seconds: 1));
      } else {
        return false;
      }
    }
  }
}
