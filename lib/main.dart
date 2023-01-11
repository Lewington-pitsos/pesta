import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:background_sms/background_sms.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart';
import 'package:pesta/notification.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pesta/bot.dart';
import 'package:pesta/task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(holdConversations, isInDebugMode: true);

  final database = await openDatabase(
    join(await getDatabasesPath(), databaseName),
    version: 2,
  );

  var tables = await database
      .rawQuery('SELECT * FROM sqlite_master WHERE name="tasks";');

  if (tables.isEmpty) {
    await database.execute("""
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taskType varchar(255) NOT NULL default '',
    activity varchar(255) NOT NULL default '',
    location varchar(255) NOT NULL default '',
    deadline int NOT NULL,
    neediness int NOT NULL,
    status varchar(255) NOT NULL
);
""");

    await database.execute("""
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taskId int NOT NULL,
  fullName varchar(255) NOT NULL default '',
  phoneNumber varchar(255) NOT NULL default '',
  phoneNumberName varchar(255) NOT NULL default '',
  CONSTRAINT fk_task,
  FOREIGN KEY (taskId) REFERENCES tasks (id)
);""");

    await database.execute("""
CREATE TABLE times (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taskId int NOT NULL,
    start int NOT NULL,
    end int NOT NULL,
    CONSTRAINT fk_task,
    FOREIGN KEY (taskId) REFERENCES tasks (id)
);
""");
    print("database created");
  } else {
    print("database already exists");
  }

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

Future<PermissionStatus> _getContactsPermission() async {
  final PermissionStatus contactsPermission = await Permission.contacts.status;
  if (contactsPermission != PermissionStatus.granted &&
      contactsPermission != PermissionStatus.denied) {
    final PermissionStatus permissionStatus =
        await Permission.contacts.request();
    return permissionStatus ?? PermissionStatus.denied;
  } else {
    return contactsPermission;
  }
}

Future<PermissionStatus> _getSMSPermission() async {
  final PermissionStatus SMSPermission = await Permission.sms.status;
  if (SMSPermission != PermissionStatus.granted &&
      SMSPermission != PermissionStatus.denied) {
    final PermissionStatus permissionStatus = await Permission.sms.request();
    return permissionStatus ?? PermissionStatus.denied;
  } else {
    return SMSPermission;
  }
}

Future<PermissionStatus> _getAllPermissions() async {
  final PermissionStatus contactsPermission = await _getContactsPermission();
  final PermissionStatus SMSPermission = await _getSMSPermission();
  if (contactsPermission == PermissionStatus.granted &&
      SMSPermission == PermissionStatus.granted) {
    return PermissionStatus.granted;
  }
  ;
  return PermissionStatus.denied;
}

class _TaskFormState extends State<TaskForm> {
  PermissionStatus permissions = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      if (permissions == PermissionStatus.granted) {
        return PestaForm();
      } else {
        Permission.sms.request().whenComplete(
            () => Permission.contacts.request().whenComplete(() async {
                  permissions = await _getAllPermissions();
                  setState(() {
                    permissions = permissions;
                  });
                }));

        return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Please grant permission to access contacts and sms"),
        ]));
      }
    });
  }
}

class PestaForm extends StatefulWidget {
  const PestaForm({super.key});

  @override
  State<PestaForm> createState() => _PestaFormState();
}

class _PestaFormState extends State<PestaForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  static List<String> tasks = [
    'Catch-Up',
    'Group Session (coming soon)',
    'Ask To Borrow (coming soon)'
  ];
  static List<String> enabledTasks = [tasks[0]];
  List<PhoneContact> contacts = [];
  Database? db;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FormBuilder(
      key: _formKey,
      onChanged: () => print("form has changed"),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: {
        "task": tasks[0],
      },
      // child:
      child: Column(
        children: [
          FormBuilderDropdown(
            name: 'task',
            items: tasks
                .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                    enabled: enabledTasks.contains(item)))
                .toList(),
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          FormBuilderTextField(
            name: "activity",
            decoration: const InputDecoration(labelText: "activity"),
            initialValue: "dinner",
          ),
          FormBuilderDateTimePicker(
            name: 'startTime',
            decoration: const InputDecoration(labelText: 'Start Time'),
            initialValue: DateTime.now().add(Duration(hours: 3)),
          ),
          FormBuilderDateTimePicker(
            name: 'endTime',
            decoration: const InputDecoration(labelText: 'End Time'),
            initialValue: DateTime.now().add(Duration(hours: 6)),
          ),
          Column(children: [
            Text("Contacts: "),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];

                  return ListTile(
                      title: Text(contact.fullName ?? "unknown contact"));
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
          ]),
          ElevatedButton(
              onPressed: contacts.length > 0
                  ? () async {
                      _formKey.currentState?.save();
                      final formData = _formKey.currentState?.value;

                      final taskType = formData?["task"];

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Starting $taskType task',
                              textScaleFactor: 1.5),
                          duration: Duration(seconds: 3)));

                      final timeOptions = DateTimeRange(
                          start: formData!['startTime'],
                          end: formData!['endTime']);

                      final task = Task(
                          contacts: contacts,
                          taskType: taskType,
                          activity: formData!['activity'],
                          times: [timeOptions]);

                      db ??= await openDatabase(
                        join(await getDatabasesPath(), databaseName),
                        version: 2,
                      );

                      final taskId = await saveTask(task, db!);

                      print('just saved task $taskId');

                      await Workmanager().registerOneOffTask(
                        DateTime.now().second.toString(),
                        task.taskType,
                        inputData: {'taskId': taskId},
                      );
                    }
                  : null,
              child: const Text("Submit"))
        ],
      ),
    ));
  }
}
