import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:fluttercontactpicker/fluttercontactpicker.dart';

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
      // child:           ContactList(),
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

class ContactList extends StatefulWidget {
  const ContactList({super.key});

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  Iterable<Contact>? _contacts;

  @override
  void initState() {
    getContacts();
    super.initState();
  }

  Future<void> getContacts() async {
    //Make sure we already have permissions for contacts when we get to this
    //page, so we can just retrieve it
    final Iterable<Contact> contacts = await ContactsService.getContacts();
    setState(() {
      _contacts = contacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children:[
        Text("contacts"),
        FormBuilderSele
      ] ),
      body: _contacts != null
          //Build a list view of all contacts, displaying their avatar and
          // display name
          FormBuilderDatePicker(),

          // ? ListView.builder(
          //     itemCount: _contacts?.length ?? 0,
          //     itemBuilder: (BuildContext context, int index) {
          //       Contact contact = _contacts!.elementAt(index);
          //       return ListTile(
          //         contentPadding:
          //             const EdgeInsets.symmetric(vertical: 2, horizontal: 18),
          //         leading:
          //             (contact.avatar != null && contact.avatar!.isNotEmpty)
          //                 ? CircleAvatar(
          //                     backgroundImage: MemoryImage(contact.avatar!),
          //                   )
          //                 : CircleAvatar(
          //                     child: Text(contact.initials()),
          //                     backgroundColor: Theme.of(context).accentColor,
          //                   ),
          //         title: Text(contact.displayName ?? ''),
          //         //This can be further expanded to showing contacts detail
          //         // onPressed().
          //       );
          //     },
          //   )
          : Center(child: const CircularProgressIndicator()),
    );
  }
}
