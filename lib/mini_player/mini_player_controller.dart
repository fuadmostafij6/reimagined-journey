import 'package:flutter/foundation.dart';
import 'package:tv_app/models/channel.dart';
import '../pages/live_tv_page.dart';

class MiniPlayerState {
  final bool isVisible;
  final String title;
  final String url;
  final Channel? channel;
  final double panelFraction; // 0 = hidden, 0.15 = minimized bar, 1 = expanded

  const MiniPlayerState({
    required this.isVisible,
    required this.title,
    required this.url,
    required this.channel,
    required this.panelFraction,
  });

  MiniPlayerState copyWith({
    bool? isVisible,
    String? title,
    String? url,
    Channel? channel,
    double? panelFraction,
  }) {
    return MiniPlayerState(
      isVisible: isVisible ?? this.isVisible,
      title: title ?? this.title,
      url: url ?? this.url,
      channel: channel ?? this.channel,
      panelFraction: panelFraction ?? this.panelFraction,
    );
  }
}

class MiniPlayerController extends ValueNotifier<MiniPlayerState> {
  MiniPlayerController()
      : super(const MiniPlayerState(
          isVisible: false,
          title: '',
          url: '',
          channel: null,
          panelFraction: 0.0,
        ));

  static final MiniPlayerController instance = MiniPlayerController();

  void show({required String title, required String url, Channel? channel}) {
    value = value.copyWith(
      isVisible: true,
      title: title,
      url: url,
      channel: channel,
      panelFraction: 1.0,
    );
    notifyListeners();
  }

  void minimize() {
    value = value.copyWith(panelFraction: 0.15);
    notifyListeners();
  }

  void expand() {
    value = value.copyWith(panelFraction: 1.0);
    notifyListeners();
  }

  void setFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    value = value.copyWith(panelFraction: clamped);
    notifyListeners();
  }

  void close() {
    value = value.copyWith(isVisible: false, panelFraction: 0.0);
    notifyListeners();
  }
}


