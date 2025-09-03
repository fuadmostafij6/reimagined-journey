import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../screens/video_player_screen.dart';

class YoutubeSearchPage extends StatefulWidget {
  const YoutubeSearchPage({super.key});

  @override
  State<YoutubeSearchPage> createState() => _YoutubeSearchPageState();
}

class _YoutubeSearchPageState extends State<YoutubeSearchPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  List<_YouTubeItem> _items = [];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _items = [];
    });
    try {
      final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}');
      final res = await http.get(url, headers: {
        'accept-language': 'en-US,en;q=0.9',
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0 Safari/537.36',
      });
      if (res.statusCode == 200) {
        final items = _parseYouTubeResults(res.body);
        setState(() {
          _items = items;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<_YouTubeItem> _parseYouTubeResults(String html) {
    final startKey = 'ytInitialData';
    final idx = html.indexOf(startKey);
    if (idx == -1) return [];
    final eqIdx = html.indexOf('=', idx);
    final endIdx = html.indexOf(';</script>', eqIdx);
    if (eqIdx == -1 || endIdx == -1) return [];
    final jsonStr = html.substring(eqIdx + 1, endIdx).trim();
    Map<String, dynamic> data;
    try {
      data = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      final doc = html_parser.parse(html);
      final anchors = doc.querySelectorAll('a#thumbnail');
      return anchors
          .map((e) => e.attributes['href'])
          .whereType<String>()
          .where((h) => h.startsWith('/watch?v='))
          .map((h) => _YouTubeItem(
                videoId: Uri.parse(h).queryParameters['v'] ?? h.replaceFirst('/watch?v=', ''),
                title: 'Video',
                thumbnailUrl: 'https://i.ytimg.com/vi/${Uri.parse(h).queryParameters['v']}/hqdefault.jpg',
              ))
          .toList();
    }

    final contents = data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
    if (contents == null) return [];
    final List<_YouTubeItem> out = [];
    for (final block in contents) {
      final itemSection = block['itemSectionRenderer'];
      if (itemSection == null) continue;
      final items = itemSection['contents'] as List?;
      if (items == null) continue;
      for (final it in items) {
        final vr = it['videoRenderer'];
        if (vr == null) continue;
        final id = vr['videoId'];
        final titleRuns = vr['title']?['runs'] as List?;
        final title = titleRuns != null && titleRuns.isNotEmpty ? (titleRuns.first['text'] ?? 'Video') : 'Video';
        final thumbs = vr['thumbnail']?['thumbnails'] as List?;
        final thumb = thumbs != null && thumbs.isNotEmpty ? (thumbs.last['url'] ?? '') : '';
        out.add(_YouTubeItem(videoId: id, title: title, thumbnailUrl: thumb));
      }
    }
    return out;
  }

  Future<void> _playVideo(BuildContext context, _YouTubeItem item) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(item.videoId);
      final streamInfo = manifest.muxed.bestQuality;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(title: item.title, url: streamInfo.url.toString()),
      ));
    } catch (_) {
    } finally {
      yt.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search YouTube videos',
                      border: InputBorder.none,
                    ),
                    onSubmitted: _search,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton.icon(
                    onPressed: () => _search(_controller.text),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Go'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('Search results will appear here'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final v = _items[i];
                    return _VideoCard(
                      item: v,
                      onTap: () => _playBestOrOfferHls(context, v),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _YouTubeItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  _YouTubeItem({required this.videoId, required this.title, required this.thumbnailUrl});
}

class _VideoCard extends StatelessWidget {
  final _YouTubeItem item;
  final VoidCallback onTap;
  const _VideoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.thumbnailUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(item.thumbnailUrl, fit: BoxFit.cover),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black54],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: Icon(Icons.play_circle_fill, size: 36, color: Colors.white),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _playBestOrOfferHls(BuildContext context, _YouTubeItem item) async {
  final yt = YoutubeExplode();
  try {
    final manifest = await yt.videos.streamsClient.getManifest(item.videoId);
    final best = manifest.muxed.bestQuality;
    if (best != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(title: item.title, url: best.url.toString()),
      ));
      return;
    }
    // fallback: offer HLS if available
    String? hls;
    try {
      final dynamic m = manifest;
      final dynamic maybeHls = m.hlsManifestUrl;
      if (maybeHls is String && maybeHls.isNotEmpty) {
        hls = maybeHls;
      }
    } catch (_) {}
    if (hls != null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Live stream available'),
            content: const Text('No regular streams found. Play live HLS instead?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(title: item.title, url: hls!),
                  ));
                },
                child: const Text('Play HLS'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No playable streams found')));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load streams')));
    }
  } finally {
    yt.close();
  }
}


