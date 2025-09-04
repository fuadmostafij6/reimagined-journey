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
  late Future<List<Channel>> _future;
  String? _error;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _future = _loadChannels();
  }

  Future<List<Channel>> _loadChannels() async {
    try {
      final urls = [
        'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/merge.json'
      ];
      final responses = await Future.wait(urls.map((u) => http.get(Uri.parse(u), headers: {
            'accept': 'application/json,text/plain,*/*',
            'user-agent': 'tv-app/1.0',
          }))); 
      final List<Channel> merged = [];
      for (final res in responses) {
        if (res.statusCode != 200) {
          _error = 'HTTP ${res.statusCode} on one source';
          continue;
        }
        final body = utf8.decode(res.bodyBytes);
        final dynamic decoded = json.decode(body);
        if (decoded is List) {
          merged.addAll(decoded
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
              .where((c) => c.url.isNotEmpty));
        } else {
          _error = 'Invalid JSON format from one source';
        }
      }
      // Deduplicate by id+url
      final Map<String, Channel> unique = {
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

  void _playChannel(Channel c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        title: c.title, 
        url: c.url,
        channel: c,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV Channels'),
        backgroundColor: const Color(0xFF1F1B2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _error = null;
                _future = _loadChannels();
              });
            },
            tooltip: 'Refresh channels',
          ),
        ],
      ),
      body: FutureBuilder<List<Channel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading channels...'),
                ],
              ),
            );
          }
          
          final allItems = snapshot.data ?? [];
          if (allItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'No channels found',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _future = _loadChannels();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final categories = ['All', ...{
            for (final c in allItems) c.category.isEmpty ? 'Unknown' : c.category
          }.toList()..sort()];
          
          final items = _selectedCategory == 'All'
              ? allItems
              : allItems.where((c) => (c.category.isEmpty ? 'Unknown' : c.category) == _selectedCategory).toList();

          return Column(
            children: [
              // Category filter chips
              Container(
                color: const Color(0xFF2B2250),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 56,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: Colors.blue,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                        },
                      );
                    },
                  ),
                ),
              ),
              
              // Channel count info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.withOpacity(0.1),
                child: Row(
                  children: [
                    Text(
                      '${items.length} channels',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Category: $_selectedCategory',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Channels grid
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
                      isFavorite: false, // For now, no favorites functionality
                      onFavoriteToggle: () {}, // Empty callback for now
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Channel {
  final String id;
  final String title;
  final String category;
  final String url;
  final String logo;
  final String tvgId;
  final String tvgChno;
  final String userAgent;
  final String cookies;
  
  Channel({
    required this.id, 
    required this.title, 
    required this.category, 
    required this.url,
    required this.logo,
    required this.tvgId,
    required this.tvgChno,
    required this.userAgent,
    required this.cookies,
  });
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  
  const _ChannelCard({
    required this.channel, 
    required this.onTap, 
    required this.isFavorite, 
    required this.onFavoriteToggle,
  });

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
              // Logo and title row
              Row(
                children: [
                  // Channel logo
                  if (channel.logo.isNotEmpty)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          channel.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.live_tv,
                                color: Colors.white70,
                                size: 20,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.live_tv,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Channel title
                  Expanded(
                    child: Text(
                      channel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),

                ],
              ),
              const Spacer(),
              // Category and additional info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            ],
          ),
        ),
      ),
    );
  }
}


