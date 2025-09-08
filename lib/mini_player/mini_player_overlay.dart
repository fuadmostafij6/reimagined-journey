import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tv_app/models/channel.dart';
import 'package:video_player/video_player.dart';
import '../pages/live_tv_page.dart';
import 'mini_player_controller.dart';

class MiniPlayerOverlay extends StatefulWidget {
  const MiniPlayerOverlay({super.key});

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    MiniPlayerController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    MiniPlayerController.instance.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController(String url, Channel? channel) async {
    if (_controller != null) {
      final same = _controller!.dataSource == url;
      if (same) return;
      await _controller!.dispose();
      _controller = null;
    }
    final headers = <String, String>{};
    // Minimal headers for stability; reuse of full headers could be added if needed
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
    _controller = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onChanged() {
    final s = MiniPlayerController.instance.value;
    if (!s.isVisible) {
      _controller?.pause();
      return;
    }
    _ensureController(s.url, s.channel);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = MiniPlayerController.instance.value;
    if (!s.isVisible) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final heightExpanded = media.size.height; // open full height initially
    final heightMinimized = 64.0;
    final h = lerpDouble(heightMinimized, heightExpanded, s.panelFraction);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: h,
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          final delta = -d.primaryDelta! / (heightExpanded - heightMinimized);
          MiniPlayerController.instance.setFraction(s.panelFraction + delta);
        },
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 300) {
            MiniPlayerController.instance.minimize();
          } else if (v < -300) {
            MiniPlayerController.instance.expand();
          } else {
            if (s.panelFraction > 0.6) {
              MiniPlayerController.instance.expand();
            } else if (s.panelFraction < 0.1) {
              MiniPlayerController.instance.close();
            } else {
              MiniPlayerController.instance.minimize();
            }
          }
        },
        onTap: () => MiniPlayerController.instance.expand(),
        child: Material(
          color: Colors.black,
          elevation: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Column(
              children: [
                // Video area
                SizedBox(
                  height: math.max(200, media.size.height * 0.4 * s.panelFraction + media.size.height * 0.3),
                  child: _controller?.value.isInitialized == true
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                // Title and controls row (height animates via overall container)
                Expanded(
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => MiniPlayerController.instance.minimize(),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                          tooltip: 'Minimize',
                        ),
                        Expanded(
                          child: Text(
                            s.title,
                            maxLines: s.panelFraction > 0.5 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            if (_controller == null) return;
                            if (_controller!.value.isPlaying) {
                              await _controller!.pause();
                            } else {
                              await _controller!.play();
                            }
                            if (mounted) setState(() {});
                          },
                          icon: Icon(
                            _controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => MiniPlayerController.instance.close(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double lerpDouble(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}


