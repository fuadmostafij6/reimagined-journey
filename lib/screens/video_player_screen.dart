import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../pages/live_tv_page.dart';

const MethodChannel _pipChannel = MethodChannel('app.pip');

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final Channel? channel;
  
  const VideoPlayerScreen({
    super.key, 
    required this.title, 
    required this.url,
    this.channel,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;
  String? _errorMessage;

  // Controls state
  bool _controlsVisible = false;
  Timer? _hideTimer;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!mounted) return;
    if (_controller?.value.isPlaying == true) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) _scheduleAutoHide();
  }

  Future<void> _seekRelative(Duration delta) async {
    final current = await _controller?.position;
    if (current == null) return;
    var target = current + delta;
    if (target < Duration.zero) target = Duration.zero;
    await _controller?.seekTo(target);
  }

  Future<void> _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    if (mounted) setState(() {});
  }

  void _enterPip() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        await _pipChannel.invokeMethod('enterPip');
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        await _pipChannel.invokeMethod('enterPip', {
          'url': widget.url,
          'headers': _getCustomHeaders(),
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PiP supported only on Android/iOS in this build')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PiP failed: $e')),
      );
    }
  }

  Map<String, String> _getCookies() {
    final cookies = <String, String>{};
    
    if (widget.channel?.cookies.isNotEmpty == true) {
      try {
        // Parse cookies similar to Python implementation
        final cookieString = widget.channel!.cookies;
        final cookiePairs = cookieString.split(';');
        
        for (final pair in cookiePairs) {
          if (pair.contains('=')) {
            final parts = pair.trim().split('=');
            if (parts.length >= 2) {
              final name = parts[0].trim();
              final value = parts.sublist(1).join('=').trim(); // Handle multiple '=' signs in value
              cookies[name] = value;
            }
          }
        }
      } catch (e) {
        print('Error parsing cookies: $e');
      }
    }
    
    return cookies;
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: _getCustomHeaders(),
      );
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.play();
      setState(() {});
      _scheduleAutoHide();
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  Map<String, String> _getCustomHeaders() {
    final headers = <String, String>{
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site',
    };

    if (widget.channel?.userAgent.isNotEmpty == true) {
      headers['User-Agent'] = widget.channel!.userAgent;
    } else {
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    }

    if (widget.channel?.tvgId.isNotEmpty == true) {
      headers['Referer'] = 'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/merge.json';
    }

    if (widget.url.contains('merichunidya.com')) {
      headers['Origin'] = 'https://merichunidya.com';
    } else if (widget.url.contains('aynaott.com')) {
      headers['Origin'] = 'https://aynaott.com';
    } else if (widget.url.contains('toffeelive.com')) {
      headers['Origin'] = 'https://toffeelive.com';
    }

    if (widget.url.endsWith('.m3u8')) {
      headers['Accept'] = 'application/vnd.apple.mpegurl, application/x-mpegURL, application/vnd.apple.mpegurl.audio';
    } else if (widget.url.endsWith('.mpd')) {
      headers['Accept'] = 'application/dash+xml,video/vnd.mpeg.dash.mpd';
    }

    final cookies = _getCookies();
    if (cookies.isNotEmpty) {
      final cookieHeader = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      headers['Cookie'] = cookieHeader;
    }

    return headers;
  }

  String _getStreamType() {
    if (widget.url.endsWith('.m3u8')) {
      return 'HLS Stream';
    } else if (widget.url.endsWith('.mpd')) {
      return 'DASH Stream';
    } else if (widget.url.endsWith('.mp4')) {
      return 'MP4 Video';
    } else if (widget.url.contains('rtmp://')) {
      return 'RTMP Stream';
    } else {
      return 'Video Stream';
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (widget.channel != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'info':
                    _showChannelInfo();
                    break;
                  case 'test':
                    _testStream();
                    break;
                  case 'refresh':
                    _refreshVideo();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: _error
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Playback Error',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refreshVideo,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : (_controller == null || !_controller!.value.isInitialized)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading video...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller!.value.aspectRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleControls,
                            onDoubleTapDown: (details) {
                              final dx = details.localPosition.dx;
                              final isLeft = dx < constraints.maxWidth / 2;
                              _seekRelative(Duration(seconds: isLeft ? -10 : 10));
                            },
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_controller!),

                                // Controls overlay
                                AnimatedOpacity(
                                  opacity: _controlsVisible ? 1 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: IgnorePointer(
                                    ignoring: !_controlsVisible,
                                    child: Container(
                                      color: Colors.black26,
                                      child: Stack(
                                        children: [
                                          // Center play/pause
                                          Center(
                                            child: IconButton(
                                              iconSize: 64,
                                              color: Colors.white,
                                              icon: Icon(
                                                _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                                              ),
                                              onPressed: () async {
                                                if (_controller!.value.isPlaying) {
                                                  await _controller!.pause();
                                                } else {
                                                  await _controller!.play();
                                                }
                                                setState(() {});
                                                _scheduleAutoHide();
                                              },
                                            ),
                                          ),

                                          // Top-right quick actions
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                                                  onPressed: _enterPip,
                                                  tooltip: 'PiP',
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: _toggleFullscreen,
                                                  tooltip: _isFullscreen ? 'Exit full screen' : 'Full screen',
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Bottom progress (only when controls shown)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              child: VideoProgressIndicator(
                                                _controller!,
                                                allowScrubbing: true,
                                                padding: EdgeInsets.zero,
                                                colors: VideoProgressColors(
                                                  playedColor: Colors.blueAccent,
                                                  bufferedColor: Colors.white38,
                                                  backgroundColor: Colors.white24,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Left and right double-tap overlays (visual hints)
                                          if (_controlsVisible) ...[
                                            Positioned(
                                              left: 16,
                                              bottom: 56,
                                              child: _SeekHint(seconds: -10),
                                            ),
                                            Positioned(
                                              right: 16,
                                              bottom: 56,
                                              child: _SeekHint(seconds: 10),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Always keep minimal progress bar hidden when controls hidden
                                if (!_controlsVisible)
                                  const SizedBox.shrink(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  void _showChannelInfo() {
    if (widget.channel == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Channel Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Title', widget.channel!.title),
              _InfoRow('Category', widget.channel!.category),
              _InfoRow('ID', widget.channel!.id),
              if (widget.channel!.tvgId.isNotEmpty)
                _InfoRow('TVG ID', widget.channel!.tvgId),
              if (widget.channel!.tvgChno.isNotEmpty)
                _InfoRow('TVG Channel', widget.channel!.tvgChno),
              _InfoRow('Stream Type', _getStreamType()),
              _InfoRow('Stream URL', widget.url),
              if (widget.channel!.userAgent.isNotEmpty)
                _InfoRow('User Agent', widget.channel!.userAgent),
              if (widget.channel!.cookies.isNotEmpty)
                _InfoRow('Cookies', widget.channel!.cookies),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _refreshVideo() {
    setState(() {
      _error = false;
      _errorMessage = null;
    });
    _controller?.dispose();
    _init();
  }

  Future<void> _testStream() async {
    if (widget.channel == null) return;
    
    try {
      final headers = _getCustomHeaders();
      print('Testing stream with headers: $headers');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing stream...'),
            ],
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stream Test Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('URL: ${widget.url}'),
              const SizedBox(height: 8),
              Text('User Agent: ${headers['User-Agent']}'),
              const SizedBox(height: 8),
              Text('Cookies: ${headers['Cookie'] ?? 'None'}'),
              const SizedBox(height: 8),
              Text('Referer: ${headers['Referer'] ?? 'None'}'),
              const SizedBox(height: 8),
              Text('Origin: ${headers['Origin'] ?? 'None'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test error: $e')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const _InfoRow(this.label, this.value);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekHint extends StatelessWidget {
  final int seconds; // negative for rewind
  const _SeekHint({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isForward ? Icons.forward_10 : Icons.replay_10, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text('${seconds.abs()}s', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}


