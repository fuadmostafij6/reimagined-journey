import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';

class MovieChannelProvider extends ChangeNotifier {
  final List<Channel> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Channel> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> refresh() async {
    _items.clear();
    _error = null;
    notifyListeners();
    await load();
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final urls = [
        'https://raw.githubusercontent.com/fuadmostafij6/super-garbanzo/refs/heads/main/movie.json',
      ];

      final responses = await Future.wait(urls.map((u) => http.get(
            Uri.parse(u),
            headers: const {
              'accept': 'application/json,text/plain,*/*',
              'user-agent': 'tv-app/1.0',
            },
          )));

      final List<String> jsonBodies = [];
      for (final res in responses) {
        if (res.statusCode != 200) {
          _error = 'HTTP ${res.statusCode} on one source';
          continue;
        }
        jsonBodies.add(utf8.decode(res.bodyBytes));
      }

      // Parse and map in a separate isolate, yielding Channel lists in batches.
      final stream = _parseInIsolate(jsonBodies, batchSize: 100);
      await for (final batch in stream) {
        // Deduplicate using id|url
        final existingKeys = _items.map((c) => '${c.id}|${c.url}').toSet();
        for (final c in batch) {
          final key = '${c.id}|${c.url}';
          if (c.url.isEmpty) continue;
          if (existingKeys.add(key)) {
            _items.add(c);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Isolate payload and parser
class _ParseMessage {
  final List<String> jsonBodies;
  final int batchSize;
  final SendPort sendPort;
  _ParseMessage(this.jsonBodies, this.batchSize, this.sendPort);
}

Stream<List<Channel>> _parseInIsolate(List<String> bodies, {int batchSize = 100}) async* {
  final receivePort = ReceivePort();
  await Isolate.spawn<_ParseMessage>(
    _isolateEntry,
    _ParseMessage(bodies, batchSize, receivePort.sendPort),
  );

  await for (final msg in receivePort) {
    if (msg is List) {
      final batch = msg.cast<Map<String, dynamic>>().map(Channel.fromJson).toList();
      yield batch;
    } else if (msg == 'done') {
      break;
    }
  }
}

void _isolateEntry(_ParseMessage message) {
  try {
    final List<Map<String, dynamic>> mapped = [];
    for (final body in message.jsonBodies) {
      final decoded = json.decode(body);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map<String, dynamic>) {
            mapped.add(e);
            if (mapped.length >= message.batchSize) {
              message.sendPort.send(List<Map<String, dynamic>>.from(mapped));
              mapped.clear();
            }
          }
        }
      }
    }
    if (mapped.isNotEmpty) {
      message.sendPort.send(List<Map<String, dynamic>>.from(mapped));
    }
  } catch (_) {
    // Swallow parsing errors per item; provider will surface generic error
  } finally {
    message.sendPort.send('done');
  }
}


