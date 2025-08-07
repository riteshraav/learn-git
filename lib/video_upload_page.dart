import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:untitled1/pose_extractor_page.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoUploadPage extends StatefulWidget {
  @override
  _VideoUploadPageState createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  File? _videoFile;
  VideoPlayerController? _controller;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  List<double>? vector;
  final picker = ImagePicker();
  bool isLoading = false;
  Future<void> _pickVideo() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      _videoFile = File(pickedFile.path);
      _initializeVideo(_videoFile!);
      print('picked file in not null');
    }
    else{
      print('pickedfile is null');
    }
  }

  Future<void> _initializeVideo(File file) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(file);
    print('controller assigned video');
    // await _controller!.initialize();
    // print('controller initialized is ${_controller!.value.isInitialized}');
    // setState(() {});
    // _controller!.play(); // Optional: auto play
    // print('controller is played');

    try {
      await _controller!.initialize();
      print('controller initialized: ${_controller!.value.isInitialized}');
      setState(() {});
    //  _controller!.play();
      print('controller is playing');
    } catch (e) {
      print('Video initialization failed: $e');
    }
  }
  List<double>? getPoseVector(Pose pose) {
    if (pose.landmarks.isEmpty) return null;

    final lm = pose.landmarks;
    List<double> vector = [];

    PoseLandmark? get(PoseLandmarkType type) => lm.containsKey(type) ? lm[type] : null;

    // --- ANGLES ---
    double? leftElbowAngle = _angle(get(PoseLandmarkType.leftShoulder), get(PoseLandmarkType.leftElbow), get(PoseLandmarkType.leftWrist));
    double? rightElbowAngle = _angle(get(PoseLandmarkType.rightShoulder), get(PoseLandmarkType.rightElbow), get(PoseLandmarkType.rightWrist));

    double? leftShoulderAngle = _angle(get(PoseLandmarkType.leftHip), get(PoseLandmarkType.leftShoulder), get(PoseLandmarkType.leftElbow));
    double? rightShoulderAngle = _angle(get(PoseLandmarkType.rightHip), get(PoseLandmarkType.rightShoulder), get(PoseLandmarkType.rightElbow));

    double? leftKneeAngle = _angle(get(PoseLandmarkType.leftHip), get(PoseLandmarkType.leftKnee), get(PoseLandmarkType.leftAnkle));
    double? rightKneeAngle = _angle(get(PoseLandmarkType.rightHip), get(PoseLandmarkType.rightKnee), get(PoseLandmarkType.rightAnkle));

    double? leftHipAngle = _angle(get(PoseLandmarkType.leftShoulder), get(PoseLandmarkType.leftHip), get(PoseLandmarkType.leftKnee));
    double? rightHipAngle = _angle(get(PoseLandmarkType.rightShoulder), get(PoseLandmarkType.rightHip), get(PoseLandmarkType.rightKnee));

    // --- NORMALIZED DISTANCES ---
    double? torsoHeight = _yDist(get(PoseLandmarkType.leftShoulder), get(PoseLandmarkType.leftHip));
    double? hipToAnkle = _yDist(get(PoseLandmarkType.leftHip), get(PoseLandmarkType.leftAnkle));
    double? wristToShoulder = _yDist(get(PoseLandmarkType.leftWrist), get(PoseLandmarkType.leftShoulder));
    double? shoulderWidth = _xDist(get(PoseLandmarkType.leftShoulder), get(PoseLandmarkType.rightShoulder));
    double? hipWidth = _xDist(get(PoseLandmarkType.leftHip), get(PoseLandmarkType.rightHip));

    // Normalize distances by torso height to make scale invariant
    double scale = (torsoHeight != null && torsoHeight > 0) ? torsoHeight : 1.0;

    vector.addAll([
      (leftElbowAngle ?? 0.0) / 180.0,
      (rightElbowAngle ?? 0.0) / 180.0,
      (leftShoulderAngle ?? 0.0) / 180.0,
      (rightShoulderAngle ?? 0.0) / 180.0,
      (leftKneeAngle ?? 0.0) / 180.0,
      (rightKneeAngle ?? 0.0) / 180.0,
      (leftHipAngle ?? 0.0) / 180.0,
      (rightHipAngle ?? 0.0) / 180.0,
      (hipToAnkle ?? 0.0) / scale,
      (wristToShoulder ?? 0.0) / scale,
      (shoulderWidth ?? 0.0) / scale,
      (hipWidth ?? 0.0) / scale,
    ]);

    print("Universal vector: $vector");
    return vector;
  }
  double? _xDist(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) return null;
    return (b.x - a.x).abs();
  }
  double? _angle(PoseLandmark? a, PoseLandmark? b, PoseLandmark? c) {
    if (a == null || b == null || c == null) return null;
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = radians * 180 / pi;
    if (angle < 0) angle += 360;
    return angle;
  }
  double? _yDist(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) return null;
    return (a.y - b.y).abs();
  }

  double cosineSimilarity(List<double> v1, List<double> v2) {
    double dot = 0, mag1 = 0, mag2 = 0;
    for (int i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    return dot / (sqrt(mag1) * sqrt(mag2));
  }
  Future<bool> _generatePoseVectorAtCurrentFrame() async  {
    setState(() {
      isLoading = true;

    });
    try {
      final currentPosition = _controller?.value.position.inMilliseconds;
      print('video file path $_videoFile');
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: _videoFile!.path,
        imageFormat: ImageFormat.PNG,
        timeMs: currentPosition!,
        quality: 100,
      );
      print('thumbnailpath is $thumbnailPath');
      if (thumbnailPath == null) {
        print("Failed to generate thumbnail");
        setState(() {
          isLoading = false;

        });
        return false;
      }

      final inputImage = InputImage.fromFilePath(thumbnailPath);
      print('inputimage is $inputImage');
      print('⚠️input image format is ${inputImage.metadata}');
      // 4. Run pose detection
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        vector = getPoseVector(poses.first);
        print("📍 Pose vector generated at paused frame:");
        print(vector);
        setState(() {
          isLoading = false;

        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('successful'),
            duration: Duration(milliseconds: 500),
          ),
        );

        return true;
      } else {
        print("⚠️ No pose detected in current frame");
        setState(() {
          isLoading = false;

        });
        return false;
      }
    } catch (e) {
      print("❌ Error generating pose vector: $e");
      return false;
    }
    finally{
      setState(() {
        isLoading = false;

      });    }
  }

  void createJson(int position)
 async {
    // ✅ Extract current frame and generate pose vector
    bool isVectorCreated =  await _generatePoseVectorAtCurrentFrame();
    if(!isVectorCreated) {
      print('vector is not created properly');
      return;
    }
      Map<String,dynamic> data = {
        "label":0,//0 for squat
        "position":position,
      };
    if(vector == null)
      {
        print('vector is null');
      }
    else{
      for(int i = 0; i < vector!.length; i++)
      {
        String vec = "vec_$i";
        data[vec] = vector![i];
      }
      String jsonString = jsonEncode(data);
      print('data is $jsonString');
      // Ensure permissions (especially on Android)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          print("❌ Storage permission denied");
          return;
        }
      }
      // Get local file
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pose_vectors.json');

      List<Map<String, dynamic>> jsonList = [];

      // Read existing data if available
      if (await file.exists()) {
        String contents = await file.readAsString();
        if (contents.trim().isNotEmpty) {
          jsonList = List<Map<String, dynamic>>.from(json.decode(contents));
        }
      }

      // Append new entry and save
      jsonList.add(data);
      await file.writeAsString(json.encode(jsonList), flush: true);

      print("✅ Pose vector added to file: ${file.path}");

    }

  }


  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  Future<void> sharePoseVectorFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/pose_vectors.json');

    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: 'Download pose_vectors.json');
    } else {
      print("⚠️ File does not exist yet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Play Video'),
        backgroundColor: Colors.blue,
        actions: [
          ElevatedButton(
            onPressed: sharePoseVectorFile,
            child: Text("Download"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children:[
            SingleChildScrollView(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: const Text('Pick Video from Gallery'),
                  ),
                  const SizedBox(height: 20),
                  if (_controller != null && _controller!.value.isInitialized) ...[
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    Slider(
                      value: _controller!.value.position.inSeconds.toDouble(),
                      max: _controller!.value.duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _controller!.seekTo(Duration(seconds: value.toInt()));
                      },
                    ),
                  ]
                  else
                    const Text("No video selected"),

                  const SizedBox(height: 20),
                  if (_controller != null && _controller!.value.isInitialized)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            createJson(0);
                            setState(() {});
                          },
                          child: Text("Start"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            createJson(1);
                            setState(() {});
                          },
                          child:Text("mid"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_controller!.value.isPlaying) {
                              // 🔸 Pause the video
                              await _controller!.pause();
                              setState(() {});

                            } else {
                              // 🔸 Play the video
                              await _controller!.play();
                              setState(() {});
                            }
                          },
                          child: Icon(
                            _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            createJson(2);
                          },
                          child: Text("end"),
                        ),
                      ],
                    )
                ],
              ),
            ),
            if(isLoading)
              Positioned(child: CircularProgressIndicator())
          ],
        ),
      ),
    );
  }
}
