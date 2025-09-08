import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_app/models/channel.dart';

class VideoPlayer1 extends StatefulWidget {
  final String title;
  final String url;
  final Channel? channel;
  final List<Channel>? relatedChannels;
  final bool movie;
  const VideoPlayer1({
    super.key,
    required this.title,
    required this.url,
    this.channel,
    this.relatedChannels,
    required this.movie,
  });

  @override
  State<VideoPlayer1> createState() => _VideoPlayer1State();
}

class _VideoPlayer1State extends State<VideoPlayer1> {
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
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    }

    if (widget.channel?.tvgId.isNotEmpty == true) {
      headers['Referer'] =
          'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/merge.json';
    }

    if (widget.url.contains('merichunidya.com')) {
      headers['Origin'] = 'https://merichunidya.com';
    } else if (widget.url.contains('aynaott.com')) {
      headers['Origin'] = 'https://aynaott.com';
    } else if (widget.url.contains('toffeelive.com')) {
      headers['Origin'] = 'https://toffeelive.com';
    }

    if (widget.url.endsWith('.m3u8')) {
      headers['Accept'] =
          'application/vnd.apple.mpegurl, application/x-mpegURL, application/vnd.apple.mpegurl.audio';
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

  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    print(widget.url);
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.url,
      headers: widget.movie ? null : _getCustomHeaders(),
    );

    _betterPlayerController = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
      ),
      betterPlayerDataSource: dataSource,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),

      body: AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: _betterPlayerController),
      ),
    );
  }
}
