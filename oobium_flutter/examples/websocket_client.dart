import 'package:flutter/material.dart';

  // final file = File('/Users/jeremydowdall/Downloads/MVI_0096.MP4');
  // final url = 'ws://${InternetAddress.loopbackIPv4.address}:4040/ws';
  // final socket = await ClientWebSocket.connect(url);
  // socket.start();
  // final result = await socket.addTask(FileSendTask(
  //     file: file,
  //     onReplace: () => true,
  //     onResume: () => Resolution.resume,
  //     onStatus: (status) => print('progress: ${status.percent}%')
  // ));
  // print('result: $result');
  // socket.close();

void main() {
  runApp(MaterialApp(
    home: App(),
  ));
}

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<App> {

  String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('File upload'),),
      body: Center(
        child: Column(
          children: [
            TextFormField(
              autofocus: false,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (text) => setState(() {
                message = text;
              }),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.cloud_upload),
              label: Text('Select Message'),
              onPressed: () => ''
            ),
          ],
        ),),
    );
  }
}

