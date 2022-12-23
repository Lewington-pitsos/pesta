import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(executeTask, isInDebugMode: true);

  final database = await openDatabase(
    join(await getDatabasesPath(), 'pesta_database.db'),
    onCreate: (db, version) {
      print('about to create the databbase table');
      return db.execute(
        'CREATE TABLE dogs(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
      );
    },
    version: 1,
  );

  print("we just connected to the database");

  final tables =
      await database.rawQuery('SELECT * FROM sqlite_master ORDER BY name;');

  print("here are the tables $tables");

  final List<Map<String, dynamic>> dogMaps = await database.query('dogs');
  final dogs = List.generate(dogMaps.length, (i) {
    return Dog(
      id: dogMaps[i]['id'],
      name: dogMaps[i]['name'],
      age: dogMaps[i]['age'],
    );
  });

  print("here are the dogs $dogs");

  var fido = const Dog(
    id: 0,
    name: 'Lido',
    age: 35,
  );

  await database.insert(
    'dogs',
    fido.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  print('inserted fido');

  final List<Map<String, dynamic>> dogMaps2 = await database.query('dogs');
  final dogs2 = List.generate(dogMaps2.length, (i) {
    return Dog(
      id: dogMaps2[i]['id'],
      name: dogMaps2[i]['name'],
      age: dogMaps2[i]['age'],
    );
  });

  print("here are the second dogs $dogs2");

  await database.delete(
    'dogs',
    // Use a `where` clause to delete a specific dog.
    where: 'id = ?',
    // Pass the Dog's id as a whereArg to prevent SQL injection.
    whereArgs: [0],
  );

  final List<Map<String, dynamic>> dogMaps3 = await database.query('dogs');
  final dogs3 = List.generate(dogMaps3.length, (i) {
    return Dog(
      id: dogMaps3[i]['id'],
      name: dogMaps3[i]['name'],
      age: dogMaps3[i]['age'],
    );
  });

  print("here are the third dogs $dogs3");

  runApp(PestaOrigin());
}

class PestaOrigin extends StatelessWidget {
  PestaOrigin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pesta',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pesta'),
        ),
        body: TaskForm(),
      ),
    );
  }
}

class TaskForm extends StatefulWidget {
  const TaskForm({super.key});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

Future<PermissionStatus> _getPermission() async {
  final PermissionStatus permission = await Permission.contacts.status;
  if (permission != PermissionStatus.granted &&
      permission != PermissionStatus.denied) {
    final Map<Permission, PermissionStatus> permissionStatus =
        await [Permission.contacts].request();
    return permissionStatus[Permission.contacts] ?? PermissionStatus.denied;
  } else {
    return permission;
  }
}

class _TaskFormState extends State<TaskForm> {
  Future<PermissionStatus> _contactsPermission = _getPermission();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PermissionStatus>(
        future: _contactsPermission,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data == PermissionStatus.granted) {
              return FormContent();
            } else {
              // TODO: handle the user's response to this in some manner
              Permission.contacts.request();

              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text("Please grant permission to access contacts"),
                  ]));
            }
          } else {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text("Loading..."),
                  CircularProgressIndicator()
                ]));
          }
        });
  }
}

class FormContent extends StatelessWidget {
  FormContent({super.key});
  final _formKey = GlobalKey<FormBuilderState>();
  static List<String> tasks = [
    'Catch-Up',
    'Group Session (coming soon)',
    'Ask To Borrow (coming soon)'
  ];
  static List<String> enabledTasks = [tasks[0]];

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FormBuilder(
      key: _formKey,
      onChanged: () => print("we like to boogy"),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: {
        "taskDropdown": tasks[0],
      },
      // child:
      child: Column(
        children: [
          FormBuilderDropdown(
            name: 'taskDropdown',
            items: tasks
                .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                    enabled: enabledTasks.contains(item)))
                .toList(),
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          FormBuilderDateTimePicker(
            name: 'startTime',
            decoration: const InputDecoration(labelText: 'Start Time'),
          ),
          FormBuilderDateTimePicker(
            name: 'endTime',
            decoration: const InputDecoration(labelText: 'End Time'),
          ),
          ContactList(),
          ElevatedButton(
              onPressed: () async {
                _formKey.currentState?.save();
                final task = _formKey.currentState?.value;

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$task', textScaleFactor: 2.2),
                    duration: Duration(seconds: 1)));

                await Workmanager().registerOneOffTask(
                    DateTime.now().second.toString(), "happy song");
              },
              child: const Text("Submit"))
        ],
      ),
    ));
  }
}

class ContactList extends StatefulWidget {
  const ContactList({super.key});

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  List<PhoneContact> contacts = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text("Contacts: "),
      SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.vertical,
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];

            return ListTile(title: Text(contact.fullName ?? "unknown contact"));
          },
        ),
      ),
      ElevatedButton(
        onPressed: () async {
          final PhoneContact contact =
              await FlutterContactPicker.pickPhoneContact();

          contacts.add(contact);

          setState(() {
            contacts = contacts;
          });
        },
        child: new Text('Add a contact'),
      ),
    ]);
  }
}
