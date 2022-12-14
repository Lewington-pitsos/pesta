import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

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

class TaskForm extends StatelessWidget {
  TaskForm({super.key});
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

class TaskSelector extends StatefulWidget {
  const TaskSelector({super.key});

  @override
  State<TaskSelector> createState() => TaskSelectorState();
}

class TaskSelectorState extends State<TaskSelector> {
  static List<String> tasks = ['Catch-Up', 'Group Session'];
  String selectedTask;

  TaskSelectorState() : selectedTask = tasks[0];

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Center(
        child: DropdownButton<String>(
          items: tasks
              .map((item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)))
              .toList(),
          value: selectedTask,
          onChanged: (value) =>
              setState(() => selectedTask = value ?? tasks[0]),
        ),
      ));
}
