import 'dart:math';

import 'package:example/main.schema.g.dart';
import 'package:flutter/material.dart';
import 'package:oobium_datastore/oobium_datastore.dart';
import 'package:path_provider/path_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/demo-data';
  final dso = DataStoreObserver();
  final ds = MainData(path, observer: dso);
  await ds.reset();
  runApp(MyApp(ds, dso));
}

class MyApp extends StatelessWidget {

  final MainData ds;
  final DataStoreObserver dso;
  MyApp(this.ds, this.dso);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oobium Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Oobium DataStore Demo',
        ds: ds,
        dso: dso
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {

  final String title;
  final MainData ds;
  final DataStoreObserver dso;
  MyHomePage({Key? key,
    required this.title,
    required this.ds,
    required this.dso,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {

  late final AnimationController controller;
  late final Animation<double> angleAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(seconds: 5));
    angleAnimation = Tween<double>(begin: 0, end: 2*pi).animate(controller);
    controller.addListener(() {
      setState(() {});
    });
    controller.repeat();
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
                        child: Text('Model Count: ${widget.dso.modelCount}', style: TextStyle(color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Record Count: ${widget.dso.recordCount}', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        child: Text('Add'),
                        onPressed: () {
                          final l = widget.ds.getItems().length;
                          widget.ds.putAll(List.generate(100, (i) => Item(id: i + l, name: 'item-1-$i')));
                        },
                      ),
                      Container(width: 16,),
                      ElevatedButton(
                        child: Text('Update'),
                        onPressed: widget.ds.getItems().isEmpty ? null : () {
                          widget.ds.putAll(List.generate(100, (i) => Item(id: i, name: 'update-${++updateTaps}-$i')));
                        },
                      ),
                      Container(width: 16,),
                      ElevatedButton(
                        child: Text('Remove'),
                        onPressed: widget.ds.getItems().isEmpty ? null : () {
                          widget.ds.removeAll(widget.ds.getItems().take(100).toList());
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        child: Text('Reset'),
                        onPressed: () {
                          widget.ds.reset();
                        },
                      ),
                    ],
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

int updateTaps = 0;