import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../screens/modern_video_player_screen.dart';

class LiveTvPage extends StatefulWidget {
  const LiveTvPage({super.key});

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  late Future<List<Channel>> _future;
  String? _error;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};

  @override
  void initState() {
    super.initState();
    _future = _loadChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
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
          // Debug: Print sample data
          if (decoded.isNotEmpty) {
            print('Sample JSON item: ${decoded.first}');
            print('Sample category: ${decoded.first['category']}');
          }
          
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

  void _playChannel(Channel c, List<Channel> allChannels) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ModernVideoPlayerScreen(
        title: c.title, 
        url: c.url,
        channel: c,
        relatedChannels: allChannels,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
          
          // Extract all unique categories from the data
          final Set<String> uniqueCategories = {};
          for (final channel in allItems) {
            final category = channel.category.trim();
            if (category.isNotEmpty) {
              uniqueCategories.add(category);
            }
          }
          
          // Convert to sorted list and add 'All' option
          final categories = ['All', ...uniqueCategories.toList()..sort()];
          
          // Debug: Print categories to console
          print('Found ${categories.length - 1} categories: ${categories.skip(1).join(', ')}');
          
          final items = _selectedCategory == 'All'
              ? allItems
              : allItems.where((c) => c.category.trim() == _selectedCategory).toList();

          // Apply search filter
          final filteredItems = _searchQuery.isEmpty
              ? items
              : items.where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return CustomScrollView(
            slivers: [
              // Search bar (scrollable)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search channels...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
              ),

              // Sticky header: categories section
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  minHeight: 130,
                  maxHeight: 130,
                  child: Container(
                    color: Colors.black,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2B2250),
                            const Color(0xFF1F1B2E),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Categories',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${categories.length - 1} categories',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (categories.length > 1)
                                    Text(
                                      '${allItems.length} total channels',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: categories.length > 1
                                ? ListView.separated(
                                    controller: _categoryScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: categories.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final cat = categories[index];
                                      final selected = cat == _selectedCategory;
                                      final isAll = cat == 'All';
                                      _categoryKeys.putIfAbsent(cat, () => GlobalKey());
                                      return AnimatedOpacity(
                                        key: _categoryKeys[cat],
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        opacity: selected ? 1.0 : 0.85,
                                        child: AnimatedScale(
                                          duration: const Duration(milliseconds: 200),
                                          scale: selected ? 1.0 : 0.96,
                                          curve: Curves.easeInOut,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell
                                            (
                                              borderRadius: BorderRadius.circular(24),
                                              onTap: () {
                                                setState(() => _selectedCategory = cat);
                                                final key = _categoryKeys[cat];
                                                if (key != null && key.currentContext != null) {
                                                  Scrollable.ensureVisible(
                                                    key.currentContext!,
                                                    alignment: 0.3,
                                                    duration: const Duration(milliseconds: 250),
                                                    curve: Curves.easeOut,
                                                  );
                                                }
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                curve: Curves.easeInOut,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                decoration: BoxDecoration(
                                                  gradient: selected
                                                      ? const LinearGradient(
                                                          colors: [Colors.blue, Colors.blueAccent],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        )
                                                      : null,
                                                  color: selected ? null : Colors.white.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: selected
                                                      ? Border.all(color: Colors.blue.withOpacity(0.3), width: 2)
                                                      : Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                  boxShadow: selected
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors.blue.withOpacity(0.3),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isAll ? Icons.all_inclusive : Icons.tv,
                                                      color: selected ? Colors.white : Colors.white70,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      cat,
                                                      style: TextStyle(
                                                        color: selected ? Colors.white : Colors.white70,
                                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      'Loading categories...',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Channel count info
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.live_tv,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${filteredItems.length} channels',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedCategory == 'All' 
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedCategory == 'All' 
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _selectedCategory == 'All' ? 'All Categories' : _selectedCategory,
                          style: TextStyle(
                            color: _selectedCategory == 'All' ? Colors.blue : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Channels grid
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 16 / 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final v = filteredItems[index];
                      return _ChannelCard(
                        channel: v,
                        onTap: () => _playChannel(v, allItems),
                        isFavorite: false, // For now, no favorites functionality
                        onFavoriteToggle: () {}, // Empty callback for now
                      );
                    },
                    childCount: filteredItems.length,
                  ),
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
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1B2E), Color(0xFF2B2250)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and title row
              Row(
                children: [
                  // Enhanced channel logo
                  if (channel.logo.isNotEmpty)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          channel.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.live_tv,
                                color: Colors.white70,
                                size: 24,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.live_tv,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 16),
                  // Enhanced channel title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 2,
              ),

              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.3),
                        Colors.blueAccent.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    channel.category.isEmpty ? 'Unknown' : channel.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}


