import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../pages/live_tv_page.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
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
      // Create video player controller with custom headers if needed
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: _getCustomHeaders(),
      );
      
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.play();
      setState(() {});
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  Map<String, String> _getCustomHeaders() {
    // Add custom headers based on channel metadata if needed
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

    // Use channel-specific user agent if available, otherwise use default
    if (widget.channel?.userAgent.isNotEmpty == true) {
      headers['User-Agent'] = widget.channel!.userAgent;
    } else {
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    }

    // Add referer if available from channel metadata
    if (widget.channel?.tvgId.isNotEmpty == true) {
      headers['Referer'] = 'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/merge.json';
    }

    // Add origin header for CORS based on stream URL
    if (widget.url.contains('merichunidya.com')) {
      headers['Origin'] = 'https://merichunidya.com';
    } else if (widget.url.contains('aynaott.com')) {
      headers['Origin'] = 'https://aynaott.com';
    } else if (widget.url.contains('toffeelive.com')) {
      headers['Origin'] = 'https://toffeelive.com';
    }

    // Add specific headers for different stream types
    if (widget.url.endsWith('.m3u8')) {
      headers['Accept'] = 'application/vnd.apple.mpegurl, application/x-mpegURL, application/vnd.apple.mpegurl.audio';
    } else if (widget.url.endsWith('.mpd')) {
      headers['Accept'] = 'application/dash+xml,video/vnd.mpeg.dash.mpd';
    }

    // Add cookies as headers if available
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
    _controller?.dispose();
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
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Channel Info'),
                    ],
                  ),
                ),
                const PopupMenuItem(
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
      
      // Show testing dialog
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
      
      // Simulate a test request (in a real app, you'd make an HTTP request)
      await Future.delayed(const Duration(seconds: 2));
      
      Navigator.of(context).pop(); // Close testing dialog
      
      // Show test results
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
              const SizedBox(height: 8),
              const Text('Note: This is a header test. For full validation, use the M3u8Validator utility.'),
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
      Navigator.of(context).pop(); // Close testing dialog
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


