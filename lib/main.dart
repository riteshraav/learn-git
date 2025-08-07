import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:untitled1/service/pose_service.dart';
import 'package:untitled1/video_upload_page.dart';

import 'PosePainter.dart';

List<CameraDescription>? cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      home: VideoUploadPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  late CameraController _cameraController;
  List<Pose>_poses = [];
  Size? _imageSize;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  late InputImage _inputImage;
  DateTime _lastSentTime = DateTime.now().subtract(Duration(seconds: 2)); // define at class level

  @override
  void initState() {
    super.initState();
    _initCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
  }

  void _initCamera() {
    _cameraController = CameraController(
      cameras![1],
      ResolutionPreset.max,
      enableAudio: false,

    );
    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _cameraController.startImageStream(_processCameraImage);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      int rotation = cameras![1].sensorOrientation;
      final inputImage = await convertYUV420ToInputImage(image,rotation);
      if (inputImage == null) {
        debugPrint('Failed to create InputImage from CameraImage');
        return;
      }
      final poses = await _poseDetector.processImage(inputImage);
      for (Pose pose in poses) {

        final landmarks = pose.landmarks.values.toList();
        final now = DateTime.now();
        if (now.difference(_lastSentTime) > Duration(seconds: 1)) {
          sendPoseToBackend(landmarks); // your existing function
          _lastSentTime = now; // update time after sending
        }
      }
      setState(() {
        _poses = poses;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
      debugPrint('successfully done everyting');
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isBusy = false;
    }
  }

  InputImage convertYUV420ToInputImage(CameraImage image, int rotation) {
    final WriteBuffer allBytes = WriteBuffer();

    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    // Convert rotation to InputImageRotation
    final inputImageRotation = InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg;

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: inputImageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
    debugPrint('format in function is ${inputImage.metadata?.format}');
    setState(() {
      _inputImage = inputImage;
    });
    return inputImage;
  }  @override
  void dispose() {
    _cameraController.dispose();
    _poseDetector.close();
    super.dispose();
  }

  Future<void> savePosesToJsonFile() async {
    // Request permission first
    final status = await Permission.storage.request();

    if (status.isGranted) {
      final jsonList = convertPosesToJson(_poses);
      final jsonString = jsonEncode(jsonList);

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/pose_data.json';
      final file = File(filePath);

      await file.writeAsString(jsonString);
      print(jsonString);
      print("✅ Pose data saved at: $filePath");
    } else {
      print("❌ Storage permission not granted");
    }
  }
  List<Map<String, dynamic>> convertPosesToJson(List<Pose> poses) {
    return poses.map((pose) {
      final landmarks = <String, dynamic>{};

      for (final type in PoseLandmarkType.values) {
        final landmark = pose.landmarks[type];
        if (landmark != null) {
          landmarks[type.name] = {
            "x": landmark.x,
            "y": landmark.y,
            "z": landmark.z,
            "inFrameLikelihood": landmark.likelihood,
          };
        }
      }

      return {
        "pose": landmarks,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Real-time Pose Detection")),
      body: Stack(
        fit:StackFit.expand,
        children: [
          CameraPreview(_cameraController),
          if (_poses.isNotEmpty && _imageSize != null)
            CustomPaint(
              painter: PosePainter(_poses,_imageSize!,_inputImage.metadata!.rotation,CameraLensDirection.front),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: savePosesToJsonFile,
        child: Icon(Icons.stop),
        tooltip: "End & Save",
      ),

    );
  }
}

