import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/video_player_screen.dart';

class LiveTvPage extends StatefulWidget {
  const LiveTvPage({super.key});

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  late Future<List<_Channel>> _future;
  String? _error;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _future = _loadChannels();
  }

  Future<List<_Channel>> _loadChannels() async {
    try {
      final urls = [
        'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/tv1.json',
        'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/tv.json',
      ];
      final responses = await Future.wait(urls.map((u) => http.get(Uri.parse(u), headers: {
            'accept': 'application/json,text/plain,*/*',
            'user-agent': 'tv-app/1.0',
          }))); 
      final List<_Channel> merged = [];
      for (final res in responses) {
        if (res.statusCode != 200) {
          _error = 'HTTP ${res.statusCode} on one source';
          continue;
        }
        final body = utf8.decode(res.bodyBytes);
        final dynamic decoded = json.decode(body);
        if (decoded is List) {
          merged.addAll(decoded
              .map((e) => _Channel(
                    id: e['id'] ?? '',
                    title: e['title'] ?? '',
                    category: e['category'] ?? 'Unknown',
                    url: e['m3u8'] ?? '',
                  ))
              .where((c) => c.url.isNotEmpty));
        }
      }
      // Deduplicate by id+url
      final Map<String, _Channel> unique = {
        for (final c in merged) '${c.id}|${c.url}': c
      };
      final list = unique.values.toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return list;
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
      return [];
    }
  }

  void _playChannel(_Channel c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(title: c.title, url: c.url),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Channel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allItems = snapshot.data ?? [];
        if (allItems.isEmpty) {
          return Center(child: Text(_error ?? 'No channels'));
        }
        final categories = ['All', ...{
          for (final c in allItems) c.category.isEmpty ? 'Unknown' : c.category
        }.toList()..sort()];
        final items = _selectedCategory == 'All'
            ? allItems
            : allItems.where((c) => (c.category.isEmpty ? 'Unknown' : c.category) == _selectedCategory).toList();

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final selected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 16 / 10,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final v = items[i];
                  return _ChannelCard(
                    channel: v,
                    onTap: () => _playChannel(v),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Channel {
  final String id;
  final String title;
  final String category;
  final String url;
  _Channel({required this.id, required this.title, required this.category, required this.url});
}

class _ChannelCard extends StatelessWidget {
  final _Channel channel;
  final VoidCallback onTap;
  const _ChannelCard({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1B2E), Color(0xFF2B2250)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.live_tv, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      channel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  channel.category.isEmpty ? 'Unknown' : channel.category,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


