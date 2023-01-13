import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

import 'package:pesta/sms.dart';

void main() {
  group("Breaking Up SMS's", () {
    test("breaks long text at 160 chars", () {
      final message =
          "000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|";
      final broken = breakUp(message);
      expect(broken.length, 3);
      expect(broken[0].length, 160);
      expect(broken[1].length, 160);
      expect(broken[2].length, 20);
    });

    test("breaks long text with spaces chars", () {
      final message =
          "000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000| 000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|";
      final broken = breakUp(message);
      expect(broken.length, 3);
      expect(broken[0].length, 100);
      expect(broken[1].length, 159);
      expect(broken[2].length, 81);
    });

    test("breaks long text with multiple spaces chars", () {
      final message =
          "000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000| 000000000|000000000|000000000 |000000000|000000000|000000000 |000000000|000000000|000000000|00000000 0|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|000000000|";
      final broken = breakUp(message);
      expect(broken.length, 3);
      expect(broken[0].length, 130);
      expect(broken[1].length, 70);
      expect(broken[2].length, 142);
    });

    test("breaks lorem ipsum text correctly", () {
      const message = """Sed ut perspiciatis unde omnis iste natus error sit 
voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque 
ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae 
dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit 
aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos 
qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui 
dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed 
quia non numquam eius modi tempora incidunt ut labore et dolore magnam 
aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum 
exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex 
ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea 
voluptate velit esse quam nihil molestiae consequatur, vel illum qui 
dolorem eum fugiat quo voluptas nulla pariatur?""";
      final broken = breakUp(message);
      expect(broken.length, 7);
      expect(broken[0].length, 123);
      expect(broken[1].length, 138);
      expect(broken[6].length, 47);
    });
  });
}
