import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const VideoPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.play();
      setState(() {});
    } catch (_) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _error
            ? const Text('Playback error')
            : (_controller == null || !_controller!.value.isInitialized)
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller!),
                        _ControlsOverlay(controller: _controller!),
                        VideoProgressIndicator(_controller!, allowScrubbing: true),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
        ),
        Positioned(
          right: 12,
          top: 12,
          child: IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () async {
              final current = await controller.position;
              if (current != null) {
                await controller.seekTo(current - const Duration(seconds: 10));
              }
            },
          ),
        ),
      ],
    );
  }
}


