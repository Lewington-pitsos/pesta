import 'package:flutter/material.dart';

void main() {
  runApp(const CorralOrigin());
}

class CorralOrigin extends StatelessWidget {
  const CorralOrigin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corral',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Corral'),
        ),
        body: Center(child: TaskSelector()),
      ),
    );
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
