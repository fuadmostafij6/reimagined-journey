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

  const Channel({
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

  static Channel fromJson(Map<String, dynamic> e) {
    return Channel(
      id: e['id'] ?? '',
      title: e['title'] ?? '',
      category: e['category'] ?? 'Unknown',
      url: e['m3u8'] ?? '',
      logo: e['logo'] ?? '',
      tvgId: e['tvg_id'] ?? '',
      tvgChno: e['tvg_chno'] ?? '',
      userAgent: e['user_agent'] ?? '',
      cookies: e['cookies'] ?? '',
    );
  }
}


