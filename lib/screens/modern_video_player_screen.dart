import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import '../pages/live_tv_page.dart';

const MethodChannel _pipChannel = MethodChannel('app.pip');

class ModernVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final Channel? channel;
  final List<Channel>? relatedChannels;
  
  const ModernVideoPlayerScreen({
    super.key, 
    required this.title, 
    required this.url,
    this.channel,
    this.relatedChannels,
  });

  @override
  State<ModernVideoPlayerScreen> createState() => _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;
  String? _errorMessage;

  // Controls state
  bool _controlsVisible = false;
  Timer? _hideTimer;
  bool _isFullscreen = false;
  bool _showTvList = false;
  
  // Ads
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;
  bool _topLoaded = false;
  bool _bottomLoaded = false;

  // Related channels
  List<Channel> _relatedChannels = [];
  int _currentChannelIndex = 0;

  // Volume and brightness control
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _initAds();
    _loadRelatedChannels();
    _initBrightness();
  }

  void _initBrightness() async {
    try {
      _currentBrightness = await ScreenBrightness().application;
    } catch (e) {
      print('Error getting current brightness: $e');
      _currentBrightness = 0.5; // Default fallback
    }
  }

  void _loadRelatedChannels() async {
    if (widget.relatedChannels != null) {
      setState(() {
        _relatedChannels = widget.relatedChannels!;
      });
    } else {
      // Load channels from the same source as LiveTvPage
      try {
        final response = await http.get(
          Uri.parse('https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/merge.json'),
          headers: {
            'accept': 'application/json,text/plain,*/*',
            'user-agent': 'tv-app/1.0',
          }
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final channels = data
              .map((e) => Channel(
                    id: e['id'] ?? '',
                    title: e['title'] ?? '',
                    category: e['category'] ?? 'Unknown',
                    url: e['m3u8'] ?? '',
                    logo: e['logo'] ?? '',
                    tvgId: e['tvg_id'] ?? '',
                    tvgChno: e['tvg_chno'] ?? '',
                    userAgent: e['user_agent'] ?? '',
                    cookies: e['cookies'] ?? '',
                  ))
              .where((c) => c.url.isNotEmpty)
              .toList();
          
          setState(() {
            _relatedChannels = channels;
          });
        }
      } catch (e) {
        print('Error loading related channels: $e');
      }
    }
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

  // Volume and brightness control methods
  void _adjustVolume(double delta) async {
    _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
    
    // Use system volume control
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      // Fallback if system sound doesn't work
    }
    
    setState(() {
      _showVolumeIndicator = true;
    });
    
    _scheduleIndicatorHide();
  }

  void _adjustBrightness(double delta) async {
    _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
    
    try {
      await ScreenBrightness().setApplicationScreenBrightness(_currentBrightness);
    } catch (e) {
      print('Error setting brightness: $e');
    }
    
    setState(() {
      _showBrightnessIndicator = true;
    });
    
    _scheduleIndicatorHide();
  }

  void _scheduleIndicatorHide() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  void _onVerticalDrag(DragUpdateDetails details, bool isLeftSide) {
    final delta = -details.delta.dy / 200.0; // Sensitivity adjustment
    
    if (isLeftSide) {
      _adjustBrightness(delta);
    } else {
      _adjustVolume(delta);
    }
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

  void _switchChannel(Channel channel) async {
    setState(() {
      _error = false;
      _errorMessage = null;
    });
    
    _controller?.dispose();
    
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(channel.url),
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

  Map<String, String> _getCookies() {
    final cookies = <String, String>{};
    
    if (widget.channel?.cookies.isNotEmpty == true) {
      try {
        final cookieString = widget.channel!.cookies;
        final cookiePairs = cookieString.split(';');
        
        for (final pair in cookiePairs) {
          if (pair.contains('=')) {
            final parts = pair.trim().split('=');
            if (parts.length >= 2) {
              final name = parts[0].trim();
              final value = parts.sublist(1).join('=').trim();
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _controller?.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  void _initAds() {
    const liveBannerId = 'ca-app-pub-5424945971440593/2553218866';
    const testBannerId = 'ca-app-pub-3940256099942544/6300978111';
    const bannerUnitId = bool.fromEnvironment('dart.vm.product') ? liveBannerId : testBannerId;
    final listener = BannerAdListener(
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() {
          if (ad == _topBannerAd) _topLoaded = true;
          if (ad == _bottomBannerAd) _bottomLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        print('Banner failed to load: $error');
        ad.dispose();
      },
    );
    _topBannerAd = BannerAd(
      adUnitId: bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    )..load();
    _bottomBannerAd = BannerAd(
      adUnitId: bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isFullscreen ? null : AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          elevation: 0,
        ),
        body: Container(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
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
                                    onPanUpdate: (details) {
                                      final dx = details.localPosition.dx;
                                      final isLeft = dx < constraints.maxWidth / 2;
                                      _onVerticalDrag(details, isLeft);
                                    },
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        // Video player
                                        _isFullscreen
                                            ? SizedBox.expand(
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: SizedBox(
                                                    width: _controller!.value.size.width,
                                                    height: _controller!.value.size.height,
                                                    child: VideoPlayer(_controller!),
                                                  ),
                                                ),
                                              )
                                            : VideoPlayer(_controller!),

                                        // Modern controls overlay
                                        AnimatedOpacity(
                                          opacity: _controlsVisible ? 1 : 0,
                                          duration: const Duration(milliseconds: 300),
                                          child: IgnorePointer(
                                            ignoring: !_controlsVisible,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black.withOpacity(0.3),
                                                    Colors.transparent,
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.7),
                                                  ],
                                                  stops: const [0.0, 0.3, 0.7, 1.0],
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Center play/pause with modern design
                                                  Center(
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // Rewind button
                                                        _ModernControlButton(
                                                          icon: Icons.replay_10,
                                                          onTap: () => _seekRelative(const Duration(seconds: -10)),
                                                        ),
                                                        const SizedBox(width: 20),
                                                        // Play/Pause button
                                                        _ModernControlButton(
                                                          icon: _controller!.value.isPlaying
                                                              ? Icons.pause_circle_filled
                                                              : Icons.play_circle_filled,
                                                          size: 80,
                                                          onTap: () async {
                                                            if (_controller!.value.isPlaying) {
                                                              await _controller!.pause();
                                                            } else {
                                                              await _controller!.play();
                                                            }
                                                            setState(() {});
                                                            _scheduleAutoHide();
                                                          },
                                                        ),
                                                        const SizedBox(width: 20),
                                                        // Fast forward button
                                                        _ModernControlButton(
                                                          icon: Icons.forward_10,
                                                          onTap: () => _seekRelative(const Duration(seconds: 10)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Top-left back button (only in fullscreen)
                                                  if (_isFullscreen)
                                                    Positioned(
                                                      left: 16,
                                                      top: 16,
                                                      child: _ModernControlButton(
                                                        icon: Icons.arrow_back,
                                                        onTap: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                      ),
                                                    ),

                                                  // Top-right controls
                                                  Positioned(
                                                    right: 16,
                                                    top: 16,
                                                    child: Row(
                                                      children: [
                                                        _ModernControlButton(
                                                          icon: Icons.chat_bubble_outline,
                                                          onTap: () {
                                                            // Chat functionality
                                                          },
                                                        ),
                                                        const SizedBox(width: 8),
                                                        _ModernControlButton(
                                                          icon: Icons.more_vert,
                                                          onTap: () {
                                                            // More options
                                                          },
                                                        ),
                                                        const SizedBox(width: 8),
                                                        _ModernControlButton(
                                                          icon: _isFullscreen
                                                              ? Icons.fullscreen_exit
                                                              : Icons.fullscreen,
                                                          onTap: _toggleFullscreen,
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Bottom info and progress
                                                  Positioned(
                                                    left: 16,
                                                    right: 16,
                                                    bottom: 16,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        // Title and episode info
                                                        Text(
                                                          widget.title,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        // const SizedBox(height: 4),
                                                        // Text(
                                                        //   'Season 3 episode 6',
                                                        //   style: TextStyle(
                                                        //     color: Colors.white.withOpacity(0.8),
                                                        //     fontSize: 14,
                                                        //   ),
                                                        // ),
                                                        const SizedBox(height: 16),
                                                        // Progress bar
                                                        _ModernProgressBar(
                                                          controller: _controller!,
                                                          onSeek: (position) async {
                                                            await _controller!.seekTo(position);
                                                          },
                                                        ),
                                                        const SizedBox(height: 8),
                                                        // Time display
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              _formatDuration(_controller!.value.position),
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Text(
                                                              _formatDuration(_controller!.value.duration),
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // TV List overlay (only in fullscreen)
                                        if (_isFullscreen && _showTvList)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 200,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.9),
                                                  ],
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  // TV List header
                                                  Container(
                                                    padding: const EdgeInsets.all(16),
                                                    child: Row(
                                                      children: [
                                                        const Text(
                                                          'Related Channels',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        IconButton(
                                                          icon: const Icon(Icons.close, color: Colors.white),
                                                          onPressed: () {
                                                            setState(() {
                                                              _showTvList = false;
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // TV List
                                                  Expanded(
                                                    child: ListView.builder(
                                                      scrollDirection: Axis.horizontal,
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                      itemCount: _relatedChannels.length,
                                                      itemBuilder: (context, index) {
                                                        final channel = _relatedChannels[index];
                                                        return Container(
                                                          width: 120,
                                                          margin: const EdgeInsets.only(right: 12),
                                                          child: _TvListItem(
                                                            channel: channel,
                                                            onTap: () => _switchChannel(channel),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                        // Volume indicator (right side)
                                        if (_showVolumeIndicator)
                                          Positioned(
                                            right: 30,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.8),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.volume_up,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: 4,
                                                      height: 100,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: Align(
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: 4,
                                                          height: 100 * _currentVolume,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(2),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '${(_currentVolume * 100).round()}%',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Brightness indicator (left side)
                                        if (_showBrightnessIndicator)
                                          Positioned(
                                            left: 30,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.8),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.brightness_6,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: 4,
                                                      height: 100,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: Align(
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: 4,
                                                          height: 100 * _currentBrightness,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(2),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '${(_currentBrightness * 100).round()}%',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ),
              // TV List at bottom (only when not fullscreen)
              if (!_isFullscreen && _relatedChannels.isNotEmpty)
                Container(
                  height: 150,
                  color: Colors.black,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Text(
                              'Related Channels',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showTvList = !_showTvList;
                                });
                              },
                              child: Text(
                                _showTvList ? 'Hide' : 'Show All',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _relatedChannels.length,
                          itemBuilder: (context, index) {
                            final channel = _relatedChannels[index];
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              child: _TvListItem(
                                channel: channel,
                                onTap: () => _switchChannel(channel),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

            ],
          ),
        ),
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
}

class _ModernControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ModernControlButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
      ),
    );
  }
}

class _ModernProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Function(Duration) onSeek;

  const _ModernProgressBar({
    required this.controller,
    required this.onSeek,
  });

  @override
  State<_ModernProgressBar> createState() => _ModernProgressBarState();
}

class _ModernProgressBarState extends State<_ModernProgressBar> {
  bool _isDragging = false;
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final position = _isDragging ? _dragPosition : widget.controller.value.position;
        final duration = widget.controller.value.duration;
        final buffered = widget.controller.value.buffered;

        if (duration.inMilliseconds == 0) {
          return const SizedBox.shrink();
        }

        final progress = position?.inMilliseconds.toDouble() ?? 0.0;
        final total = duration.inMilliseconds.toDouble();

        return GestureDetector(
          onTapDown: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final relativePosition = localPosition.dx / box.size.width;
            final newPosition = Duration(
              milliseconds: (relativePosition * total).round(),
            );
            widget.onSeek(newPosition);
          },
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
            });
          },
          onPanUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final relativePosition = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
            setState(() {
              _dragPosition = Duration(
                milliseconds: (relativePosition * total).round(),
              );
            });
          },
          onPanEnd: (details) {
            if (_dragPosition != null) {
              widget.onSeek(_dragPosition!);
            }
            setState(() {
              _isDragging = false;
              _dragPosition = null;
            });
          },
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                // Buffered progress
                ...buffered.map((range) {
                  final start = range.start.inMilliseconds / total;
                  final end = range.end.inMilliseconds / total;
                  return Positioned(
                    left: start * MediaQuery.of(context).size.width,
                    right: (1 - end) * MediaQuery.of(context).size.width,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
                // Played progress
                Positioned(
                  left: 0,
                  right: (1 - progress / total) * MediaQuery.of(context).size.width,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  left: (progress / total) * MediaQuery.of(context).size.width - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TvListItem extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _TvListItem({
    required this.channel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Channel logo
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: channel.logo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          channel.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.live_tv,
                                color: Colors.white70,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.live_tv,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
              ),
            ),
            // Channel title
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(
                  channel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
