import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:sensors_plus/sensors_plus.dart';

//設定値
class _AppConfig {
  static const double shakeThreshold = 15.0;
}

//ファイル保存
class _FileStorage {
  Future<bool> saveImage(XFile imageFile) async {
    try {
      await Gal.putImage(imageFile.path);
      return true;
    } catch (e) {
      return false;
    }
  }
}

//モーションセンサー
class _MotionSensor {
  StreamSubscription? _accelerometerSubscription;

  void startListening(void Function(AccelerometerEvent event) onData) {
    _accelerometerSubscription = accelerometerEventStream().listen(onData);
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
  }
}


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Encounter Camera',
      home: CameraScreen(),
    );
  }
}


class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  //カメラコントローラー
  CameraController? _cameraController;

  //初期化済みかのフラグ
  bool _isCameraInitialized = false;

  //写真撮影中かのフラグ
  bool _isTakingPicture = false;

  //センサーとストレージ
  final _MotionSensor _motionSensor = _MotionSensor();
  final _FileStorage _fileStorage = _FileStorage();
  
  //利用可能なカメラのリスト
  List<CameraDescription> _cameras = [];
  //現在選択中のカメラの向き
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndSensor();
  }

  //カメラとセンサーの初期化
  Future<void> _initializeCameraAndSensor() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras found');
      }
      _initializeCameraController();
      _motionSensor.startListening(_onSensorDataReceived);
    } catch (e) {
      _showInitializationErrorDialog();
    }
  }

  Future<void> _initializeCameraController() async {
      final initialCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == _currentLensDirection,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        initialCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
  }

  //センサーデータ受信時の処理
  void _onSensorDataReceived(AccelerometerEvent event) {
    final double acceleration =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
    if (acceleration > _AppConfig.shakeThreshold) {
      _takePicture();
    }
  }

  //写真撮影
  Future<void> _takePicture() async {
    if (_isTakingPicture || !_isCameraInitialized || _cameraController == null) return;

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      final success = await _fileStorage.saveImage(image);
      _showPictureTakenSnackbar(success);
    } catch (e) {
      _showPictureTakenSnackbar(false);
    } finally {
       if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  //カメラ切り替え
  Future<void> switchCamera() async {
    try{
        //カメラの向きを変えるコードを実装してみよう！
        //初期化周りのコードにヒントになる実装があるので、
        //それを参考にしてみよう！


    } catch (e) {
       _showInitializationErrorDialog();
    }
  }


  @override
  void dispose() {
    _cameraController?.dispose();
    _motionSensor.stopListening();
    super.dispose();
  }

  //初期化失敗時のダイアログ
  void _showInitializationErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: const Text('カメラの初期化に失敗しました。アプリを終了します。'),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  //写真保存結果のSnackBar
  void _showPictureTakenSnackbar(bool success) {
    if (!mounted) return;
    if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真が保存されました。')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真の保存に失敗しました。')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized && _cameraController != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 60.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: switchCamera,
                            icon: const Icon(Icons.flip_camera_ios),
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
