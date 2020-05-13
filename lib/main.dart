// 參考資料: https://juejin.im/post/5d2a0f4be51d454fa33b196f
// 參考資料: https://s0pub0dev.icopy.site/packages/flutter_downloader

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'package:toast/toast.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ReceivePort _port = ReceivePort();

  ProgressDialog progressDialog;

  @override
  void initState() {
    super.initState();
    initProgressDialog();
    _initFlutterDownloader();
  }

  void initProgressDialog() {
    // 初始化進度條
    progressDialog = ProgressDialog(context, type: ProgressDialogType.Download);
  }

  Future<void> _initFlutterDownloader() async {
    // 設定下載回撥
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];

      progressDialog.update(message: '下載中');
      // 列印輸出下載資訊
      print(
          'Download task ($id) is in status ($status) and process ($progress)');
      if (!progressDialog.isShowing()) {
        progressDialog.show();
      }
      if (status == DownloadTaskStatus.running) {
        progressDialog.update(
            progress: progress.toDouble(), message: "下載中，請稍後…");
      }
      if (status == DownloadTaskStatus.failed) {
        Toast.show('下載異常，請稍後重試', context);
        if (progressDialog.isShowing()) {
          progressDialog.hide();
        }
      }
      if (status == DownloadTaskStatus.complete) {
        if (progressDialog.isShowing()) {
          Future.delayed(
            Duration(seconds: 1),
            () => progressDialog.hide(),
          );
        }
      }
    });
    await FlutterDownloader.initialize();
    FlutterDownloader.registerCallback(_downloadCallback);
  }

  static void _downloadCallback(
    String id,
    DownloadTaskStatus status,
    int progress,
  ) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Text('下載'),
              onPressed: () => _doDownloadOperation(),
            ),
          ],
        ),
      ),
    );
  }

  void _doDownloadOperation() async {
    final isPermitted = await _checkPermission();
    if (!isPermitted) return;
    final savePath = await _findLocalPath();
    await _downloadFile(
        'https://pic.pimg.tw/gsmboy/1382549990-622805522.jpg', savePath);
  }

  // 申請許可權
  Future<bool> _checkPermission() async {
    // 先對所在平臺進行判斷
    if (Theme.of(context).platform == TargetPlatform.android) {
      PermissionStatus permission = await PermissionHandler()
          .checkPermissionStatus(PermissionGroup.storage);
      if (permission != PermissionStatus.granted) {
        Map<PermissionGroup, PermissionStatus> permissions =
            await PermissionHandler()
                .requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  // 獲取儲存路徑
  Future<String> _findLocalPath() async {
    // 因為Apple沒有外接儲存，所以第一步我們需要先對所在平臺進行判斷
    // 如果是android，使用getExternalStorageDirectory
    // 如果是iOS，使用getApplicationSupportDirectory
    final directory = Theme.of(context).platform == TargetPlatform.android
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    final localPath = directory.path + '/download';
    final savedDir = Directory(localPath);
    final isDirExists = await savedDir.exists();
    if (!isDirExists) savedDir.create();
    debugPrint('path: $localPath');
    final isImageExist = await Directory('$localPath/1382549990-622805522.jpg').exists();
    debugPrint('file path: $localPath/1382549990-622805522.jpg');
    debugPrint('file exist: $isImageExist');
    return localPath;
  }

  // 根據 downloadUrl 和 savePath 下載檔案
  Future<void> _downloadFile(downloadUrl, savePath) async =>
      await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: savePath,
        showNotification: true,
        // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
}