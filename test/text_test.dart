import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

import 'package:pesta/task.dart';
import 'package:pesta/conversation.dart';
import 'package:pesta/text.dart';

void main() {
  group(
      "Response Options",
      () => {
            test("creates all options", () {
              final c = Conversation(
                  "Bob", "Alice", "+612378213", "dinner", "the pub", [
                DateTimeRange(
                    start: DateTime(2020, 1, 1, 12, 0),
                    end: DateTime(2020, 1, 1, 13, 0)),
                DateTimeRange(
                    start: DateTime(2020, 1, 1, 13, 0),
                    end: DateTime(2020, 1, 1, 14, 0)),
                DateTimeRange(
                    start: DateTime(2020, 1, 1, 14, 0),
                    end: DateTime(2020, 1, 1, 15, 0)),
              ]);

              final options = responseOptions(c);

              expect(options.contains("a -"), true);
              expect(options.contains("b -"), true);
              expect(options.contains("c -"), true);
              expect(options.contains("d -"), true);
              expect(options.contains("e -"), true);
              expect(options.contains("f -"), false);
            })
          });
}
