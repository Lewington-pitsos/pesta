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
  static List<String> tasks = ['Catch-Up', 'Group Session'];

  @override
  Widget build(BuildContext context) {
    return Center(
        child: FormBuilder(
      key: _formKey,
      onChanged: () => print("we like to boogy"),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: {
        "textField": "why the heck not?",
        "taskDropdown": tasks[0],
      },
      child: Column(
        children: [
          FormBuilderDropdown(
              name: 'taskDropdown',
              items: tasks
                  .map((item) =>
                      DropdownMenuItem<String>(value: item, child: Text(item)))
                  .toList()),
          FormBuilderTextField(name: "textField"),
          ElevatedButton(
              onPressed: () {
                _formKey.currentState?.reset();
                FocusScope.of(context).unfocus();
              },
              child: const Text("Reset"))
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
