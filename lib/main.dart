import 'package:flutter/material.dart';
import 'pages/youtube_search_page.dart';
import 'pages/live_tv_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
    return MaterialApp(
      title: 'TV & YouTube',
      theme: theme,
      home: const RootScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  final _pages = const [
    YoutubeSearchPage(),
    LiveTvPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(_index == 0 ? 'YouTube Search' : 'Live TV'),
      //   centerTitle: true,
      // ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.live_tv), label: 'Live TV'),
        ],
      ),
    );
  }
}
