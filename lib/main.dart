import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';

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
        body: const Center(child: RandomWords()),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({super.key});

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);

  @override
  Widget build(BuildContext context) {
    final wordPair = WordPair.random();
    return ListView.builder(
      padding: const EdgeInsets.all(26.0),
      itemBuilder: /*1*/ (context, i) {
        if (i.isOdd) return const Divider(); /*2*/

        final index = i ~/ 2; /*3*/
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10)); /*4*/
        }
        return ListTile(
            title: Center(
          child: Text(
            _suggestions[index].asPascalCase,
            style: _biggerFont,
          ),
        ));
      },
    );
  }
}
