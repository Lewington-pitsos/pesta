import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

import 'package:pesta/task.dart';

void main() {
  group(
      "Task",
      () => {
            test("Formats numbers correctly", () {
              final c =
                  PhoneContact("Paul", PhoneNumber("04 1234 5555", "mobile"));
              expect(c.phoneNumber?.number, "04 1234 5555");
              expect(formatNumber(c.phoneNumber!.number!), "+61412345555");
            }),
            test("Formats numbers on instantiation", () {
              final c =
                  PhoneContact("Paul", PhoneNumber("04 1234 1678", "mobile"));
              final t = Task(
                  contacts: [c],
                  taskType: TaskType.catchUp,
                  activity: "dinner",
                  times: [
                    DateTimeRange(
                        start:
                            DateTime.fromMillisecondsSinceEpoch(1671925246654),
                        end: DateTime.fromMillisecondsSinceEpoch(1671933376654))
                  ]);
              expect(t.contacts[0].phoneNumber?.number, "+61412341678");
            })
          });
}
