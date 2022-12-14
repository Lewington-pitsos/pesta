import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(CorralOrigin());
}

class CorralOrigin extends StatelessWidget {
  CorralOrigin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corral',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Corral'),
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

class _TaskFormState extends State<TaskForm> {
  late PermissionStatus _contactsPermission;

  @override
  void initState() {
    super.initState();
    // _contactsPermission = await _getPermission();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(builder: (context, snapshot) {
      return FormContent();
    });
  }

  // Future<PermissionStatus> _getPermission() async {
  //   final PermissionStatus permission = await Permission.contacts.status;
  //   if (permission != PermissionStatus.granted &&
  //       permission != PermissionStatus.denied) {
  //     final Map<Permission, PermissionStatus> permissionStatus =
  //         await [Permission.contacts].request();
  //     return permissionStatus[Permission.contacts] ?? PermissionStatus.denied;
  //   } else {
  //     return permission;
  //   }
  // }
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
          ElevatedButton(
              onPressed: () {
                _formKey.currentState?.save();
                final task = _formKey.currentState?.value;

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$task', textScaleFactor: 2.2),
                    duration: Duration(seconds: 1)));
              },
              child: const Text("Submit"))
        ],
      ),
    ));
  }
}
