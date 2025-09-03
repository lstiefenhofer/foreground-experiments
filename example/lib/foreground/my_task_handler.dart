import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:dart_duckdb/dart_duckdb.dart';

//import 'package:path_provider/path_provider.dart';

class MyTaskHandler extends TaskHandler {

static const String exportDbCommand = 'exportDb';

  //set up example stream
  late Stream myStream;

  Stream<int> increasingCount() {
    final controller = StreamController<int>.broadcast();
    int counter = 0;   

    Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        counter++;
        controller.add(counter);
    });

    return controller.stream;
  }

  StreamSubscription? subscription;

  //db stuff
  late Database db;
  late Connection conn;


  Future<void> setupDb() async {
    db = await duckdb.open(':memory:');
    conn = await duckdb.connect(db);
    await conn.execute('''
        CREATE TABLE IF NOT EXISTS myDb 
          (counts INTEGER);
          ''');
    print('db set up');
  }

  bool closeDb() {
    conn.dispose();
    db.dispose();
    print('db closed');
    return true;
  }

  void startListening() {
    subscription = myStream.listen((event) {
      insertIntoDb(event);
      print('inserted: $event');
    });
  }

  void stopListening() async {
    await subscription?.cancel();
    subscription = null;
    print('stopped listening');
  }

  void exportCsv() async {  
    //final dir = await getExternalStorageDirectory();  
    final path = '/storage/emulated/0/Android/data/com.pravera.flutter_foreground_task_example/files/output_foreground.csv';
  
    print(path);

    try {
      await conn.execute('''COPY myDb TO '$path' (FORMAT csv);''');
      if (await io.File(path).exists()) {
        print('csv exported to $path');
      }
    }
    catch (e) {
      print(e);
    }
  }

  // inserts example value into db
  void insertIntoDb(int value) async {
    await conn.execute('''INSERT INTO myDb VALUES ($value)''');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Hello MyTaskHandler ily',
      notificationText: 'count: $value',
    );

    // Send data to main isolate.
    FlutterForegroundTask.sendDataToMain(value);
  }

  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await setupDb();
    myStream = increasingCount();
    startListening();
    print('onStart(starter: ${starter.name})');
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    stopListening();
    exportCsv();
    closeDb();
    print('onDestroy(isTimeout: $isTimeout)');
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');
    if (data == exportDbCommand) {
      exportCsv();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    //flush buffer 
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}

