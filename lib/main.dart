import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart';
import 'package:pesta/notification.dart';
import 'package:pesta/text.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pesta/bot.dart';
import 'package:pesta/task.dart';
import 'package:pesta/conversation.dart';
import 'package:pesta/sms.dart';
import 'package:diacritic/diacritic.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    quorum int NOT NULL,
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

  // await sendSms(
  //     "+XXXXX",
  //     removeDiacritics(
  //         "Hi, Jack I'm a bot. Louka sent me to ask if you want to do pesta jam session ft. jack, dylan, louka and lawrence at 2/29 bell steeet hawthorb. I can only understand these single letter responses:"));
  // print("sent sms");

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
        body: WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  static const String nameKey = 'user-name';
  String name = "Your Name";
  late SharedPreferences data;

  Future _loadName() async {
    data = await SharedPreferences.getInstance();

    final storedName = data.getString(nameKey) ?? '';

    print("collected stored name $storedName");

    if (storedName != '') {
      setState(() {
        name = storedName;
      });
    }
  }

  @override
  void initState() {
    _loadName();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text(
          "Welcome",
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 5),
        Container(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: EditableText(
              textAlign: TextAlign.center,
              backgroundCursorColor: const Color.fromARGB(255, 200, 200, 200),
              controller: TextEditingController(text: name),
              focusNode: FocusNode(),
              style: const TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontSize: 20,
                fontStyle: FontStyle.italic,
              ),
              cursorColor: Color.fromARGB(255, 30, 30, 30),
              onChanged: (value) => data.setString(nameKey, value),
              onSubmitted: (value) async =>
                  await data.setString(nameKey, value),
            )),
        SizedBox(height: 40),
        ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NewTaskScreen(),
                ),
              );
            },
            child: const Text("New Task")),
        ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TasksScreen(),
                ),
              );
            },
            child: const Text("View Tasks"))
      ],
    );
  }
}

class NewTaskScreen extends StatelessWidget {
  const NewTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('New Task'),
        ),
        body: TaskForm());
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

  if (SMSPermission == PermissionStatus.permanentlyDenied ||
      contactsPermission == PermissionStatus.permanentlyDenied) {
    return PermissionStatus.permanentlyDenied;
  }

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
        Permission.sms.request().whenComplete(() =>
            Permission.contacts.request().whenComplete(() async {
              permissions = await _getAllPermissions();

              if (mounted) {
                if (permissions == PermissionStatus.permanentlyDenied ||
                    permissions == PermissionStatus.denied) {
                  showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                            title: const Text('Permissions Needed'),
                            content:
                                const Text('This app needs SMS and Contacts '
                                    'permissions to work properly. Please '
                                    'grant them in the app settings.'),
                            actions: [
                              TextButton(
                                child: const Text("OK"),
                                onPressed: () {
                                  openAppSettings();
                                },
                              )
                            ],
                          ));
                } else {
                  // checks if the widget still exists
                  setState(() {
                    permissions = permissions;
                  });
                }
              }
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
    taskToNameMap[TaskType.notification]!,
    taskToNameMap[TaskType.catchUp]!,
    taskToNameMap[TaskType.groupSession]!,
    taskToNameMap[TaskType.askToBorrow]!,
  ];
  static List<String> enabledTasks = [tasks[0], tasks[1]];
  TaskType taskType = TaskType.notification;
  List<PhoneContact> contacts = [];
  Database? db;
  List<DateTimeRange> times = [];
  bool canAddTimes = true;

  @override
  void initState() {
    super.initState();
  }

  bool get _timeBasedTask {
    return taskType == TaskType.groupSession || taskType == TaskType.catchUp;
  }

  DateTimeRange? _getTime() {
    _formKey.currentState?.save();
    final formData = _formKey.currentState?.value;

    if (formData == null) {
      return null;
    }

    if (formData['startTime'] == null || formData['endTime'] == null) {
      return null;
    }

    if (formData['startTime']!.isAfter(formData['endTime']!)) {
      return null;
    }

    return DateTimeRange(
        start: formData!['startTime'], end: formData!['endTime']);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FormBuilder(
      key: _formKey,
      onChanged: () {
        _formKey.currentState?.save();
        final formData = _formKey.currentState?.value;
        taskType = nameToTaskMap[formData!['task']!]!;
        setState(() {
          taskType = taskType;
        });
      },
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
                    enabled: enabledTasks.contains(item),
                    child: enabledTasks.contains(item)
                        ? Text(item)
                        : Text(item,
                            style: const TextStyle(color: Colors.grey))))
                .toList(),
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          FormBuilderTextField(
            name: "activity",
            decoration: const InputDecoration(labelText: "description"),
          ),
          _timeBasedTask
              ? Column(key: Key("time-and-quarum"), children: [
                  Text("Time Windows (${times.length})"),
                  SizedBox(
                    height: 100,
                    child: Wrap(
                        direction: Axis.horizontal,
                        children: times
                            .map((t) => Container(
                                padding: EdgeInsets.all(4),
                                child: Text(compactFormat(t) + ',')))
                            .toList()),
                  ),
                  Row(children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          child: FormBuilderDateTimePicker(
                            name: 'startTime',
                            decoration:
                                const InputDecoration(labelText: 'Start Time'),
                            initialValue:
                                DateTime.now().add(Duration(hours: 3)),
                            onChanged: (time) => {
                              if (!times.contains(_getTime()))
                                {
                                  setState(() {
                                    canAddTimes = true;
                                  })
                                }
                            },
                          )),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          child: FormBuilderDateTimePicker(
                            name: 'endTime',
                            decoration:
                                const InputDecoration(labelText: 'End Time'),
                            initialValue:
                                DateTime.now().add(Duration(hours: 6)),
                            onChanged: (time) => {
                              if (!times.contains(_getTime()))
                                {
                                  setState(() {
                                    canAddTimes = true;
                                  })
                                }
                            },
                          )),
                    )
                  ]),
                  ElevatedButton(
                      onPressed: canAddTimes
                          ? () {
                              final time = _getTime();

                              if (time != null) {
                                times.add(time);
                                setState(() {
                                  times = times;
                                  canAddTimes = false;
                                });
                              }
                            }
                          : null,
                      child: Text('Add Time')),
                  const Text("Minimum attendees: "),
                  Container(
                      padding: EdgeInsets.only(left: 20, right: 20),
                      child: FormBuilderSlider(
                          enabled: contacts.length > 1,
                          name: 'quorum',
                          initialValue: 1,
                          min: 1,
                          max: contacts.length > 1
                              ? contacts.length.toDouble()
                              : 1,
                          divisions:
                              contacts.length > 1 ? contacts.length - 1 : 1)),
                ])
              : Column(),
          Column(children: [
            Text(_timeBasedTask
                ? "invitees: (${contacts.length})"
                : "recipients: (${contacts.length})"),
            SizedBox(
              height: 100,
              child: Wrap(
                  direction: Axis.horizontal,
                  children: contacts
                      .map((c) => Container(
                          padding: EdgeInsets.all(4),
                          child: Text((c.fullName ?? "unknown contact") + ',')))
                      .toList()),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final PhoneContact contact =
                      await FlutterContactPicker.pickPhoneContact();

                  contacts.add(contact);

                  setState(() {
                    contacts = contacts;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Failed to add contact'),
                      duration: Duration(seconds: 2)));
                }
              },
              child: new Text('Add a contact'),
            ),
          ]),
          ElevatedButton(
              onPressed:
                  contacts.length > 0 && (times.length > 0 || !_timeBasedTask)
                      ? () async {
                          _formKey.currentState?.save();
                          final formData = _formKey.currentState?.value;

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Starting $taskType task',
                                  textScaleFactor: 1.5),
                              duration: Duration(seconds: 3)));

                          final task = Task(
                              id: 0, // placeholder until we save.
                              contacts: contacts,
                              taskType: taskType!,
                              activity: formData!['activity'],
                              times: times,
                              quorum: _timeBasedTask
                                  ? formData['quorum'].toInt() + 1
                                  : 1);

                          db ??= await openDatabase(
                            join(await getDatabasesPath(), databaseName),
                            version: 2,
                          );

                          final taskId = await saveTask(task, db!);

                          print('just saved task $taskId');

                          await Workmanager().registerOneOffTask(
                            DateTime.now().second.toString(),
                            taskToNameMap[task.taskType]!,
                            inputData: {'taskId': taskId},
                          );

                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const TasksScreen(),
                            ),
                          );
                        }
                      : null,
              child: const Text("Submit"))
        ],
      ),
    ));
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
        ),
        body: const Text("tasks go here"));
  }
}
