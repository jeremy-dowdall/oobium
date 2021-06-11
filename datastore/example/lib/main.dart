import 'dart:math';

import 'package:example/main.schema.g.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/demo-data';
  runApp(MyApp(
    ds: await MainData(path, isolate: 'll').open(),
  ));
}

class MyApp extends StatelessWidget {

  final MainData ds;
  MyApp({required this.ds});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oobium Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Oobium DataStore Demo',
        ds: ds
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {

  final String title;
  final MainData ds;
  MyHomePage({Key? key, required this.title, required this.ds}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {

  late final AnimationController controller;
  late final Animation<double> angleAnimation;

  var streamNew = false;
  var streamDup = false;
  void stream() async {
    if(streamNew) {
      final author = widget.ds.getAuthors().first;
      widget.ds.putAll(List.generate(100, (i) => Book(title: 'test-1-$i', author: author)));
    }
    if(streamDup) {
      final book = widget.ds.getBooks().first;
      widget.ds.putAll(List.generate(100, (i) => book.copyWith(title: 'test-1-$i')));
    }
    await Future.delayed(Duration(milliseconds: 1));
    stream();
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(seconds: 5));
    angleAnimation = Tween<double>(begin: 0, end: 2*pi).animate(controller);
    controller.addListener(() {
      setState(() {});
    });
    controller.repeat();
    stream();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: angleAnimation.value,
              child: Container(
                height: 200,
                width: 200,
                color: theme.primaryColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Authors: ${widget.ds.getAuthors().length}', style: TextStyle(color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Books: ${widget.ds.getBooks().length}', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Authors'),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Add New'),
                    onPressed: () {
                      widget.ds.putAll(List.generate(100, (i) => Author(name: 'test-1-$i')));
                    },
                  ),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Add Dup'),
                    onPressed: () {
                      final model = widget.ds.getAuthors().first;
                      widget.ds.putAll(List.generate(100, (i) => model.copyWith(name: '${model.name}/test-1-$i')));
                    },
                  ),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Reset'),
                    onPressed: () {
                      widget.ds.removeAll(widget.ds.getAuthors().toList());
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('New Books'),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Start'),
                    onPressed: () => streamNew = true,
                  ),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Stop'),
                    onPressed: () => streamNew = false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Dup Books'),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Start'),
                    onPressed: () => streamDup = true,
                  ),
                  Container(width: 16,),
                  ElevatedButton(
                    child: Text('Stop'),
                    onPressed: () => streamDup = false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
