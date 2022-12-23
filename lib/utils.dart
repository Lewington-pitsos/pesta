import 'dart:async' show Future;
import 'dart:convert' show json;
import 'package:flutter/services.dart' show rootBundle;
import 'package:workmanager/workmanager.dart';

class Secret {
  final String SecretKey;
  Secret({this.SecretKey = ""});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(SecretKey: jsonMap["SecretKey"]);
  }

  @override
  String toString() {
    return 'Secret{id: $SecretKey}';
  }
}

class SecretLoader {
  final String secretPath;

  SecretLoader({required this.secretPath});
  Future<Secret> load() {
    return rootBundle.loadStructuredData<Secret>(this.secretPath,
        (jsonStr) async {
      final secret = Secret.fromJson(json.decode(jsonStr));
      return secret;
    });
  }
}

class Dog {
  final int id;
  final String name;
  final int age;

  const Dog({
    required this.id,
    required this.name,
    required this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
    };
  }

  // Implement toString to make it easier to see information about
  // each dog when using the print statement.
  @override
  String toString() {
    return 'Dog{id: $id, name: $name, age: $age}';
  }
}

void executeTask() {
  Workmanager().executeTask((taskName, inputData) async {
    print("this is the task $taskName");
    print("this is the inputData $inputData");

    for (var i = 0; i < 30; i++) {
      await Future.delayed(Duration(seconds: 1));
      print("performing $taskName");
    }

    return Future.value(true);
  });
}
