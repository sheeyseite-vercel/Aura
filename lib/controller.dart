import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

String artistOf(SongModel s) =>
    (s.artist == null || s.artist == '<unknown>') ? 'Unknown artist' : s.artist!;

Color fallbackColor(int id) =>
    HSVColor.fromAHSV(1, (id * 47 % 360).toDouble(), 0.65, 0.6).toColor();

/// Picks a rich, dark-friendly colour from the cover art.
Future<Color?> dominantColor(Uint8List bytes) async {
  try {
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
    final frame = await codec.getNextFrame();
    final data =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    double r = 0, g = 0, b = 0, w = 0;
    for (int i = 0; i + 3 < data.lengthInBytes; i += 4) {
      final rr = data.getUint8(i);
      final gg = data.getUint8(i + 1);
      final bb = data.getUint8(i + 2);
      final hsv = HSVColor.fromColor(Color.fromARGB(255, rr, gg, bb));
      final wt = hsv.saturation * hsv.value + 0.02;
      r += rr * wt;
      g += gg * wt;
      b += bb * wt;
      w += wt;
    }
    if (w == 0) return null;
    final c = Color.fromARGB(
        255, (r / w).round(), (g / w).round(), (b / w).round());
    final hsv = HSVColor.fromColor(c);
    return hsv
        .withSaturation(hsv.saturation.clamp(0.5, 0.9).toDouble())
        .withValue(hsv.value.clamp(0.45, 0.75).toDouble())
        .toColor();
  } catch (_) {
    return null;
  }
}

class PlayerController extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final OnAudioQuery query = OnAudioQuery();

  List<SongModel> songs = [];
  bool loading = true;
  bool denied = false;
  int index = 0;
  int focus = 0;
  int direction = 1; // +1 next, -1 previous (drives the slide animation)
  bool playing = false;
  bool shuffle = false;
  LoopMode loop = LoopMode.off;
  Color color = const Color(0xFFB8651C);
  Uint8List? art;

  int _artToken = 0;
  bool _wired = false;
  String _widgetArtPath = '';

  SongModel? get current => songs.isEmpty ? null : songs[index];

  Future<void> init() async {
    loading = true;
    denied = false;
    notifyListeners();
    try {
      var ok = await query.permissionsStatus();
      if (!ok) ok = await query.permissionsRequest();
      if (!ok) {
        denied = true;
        loading = false;
        notifyListeners();
        return;
      }
      final all = await query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      songs = all
          .where((s) =>
              (s.isMusic ?? false) && (s.duration ?? 0) > 30000 && s.uri != null)
          .toList();
      if (songs.isEmpty) {
        loading = false;
        notifyListeners();
        return;
      }
      final children = songs
          .map((s) => AudioSource.uri(
                Uri.parse(s.uri!),
                tag: MediaItem(
                  id: '${s.id}',
                  title: s.title,
                  artist: artistOf(s),
                  album: s.album,
                  artUri: Uri.parse(
                      'content://media/external/audio/albumart/${s.albumId}'),
                ),
              ))
          .toList();
      await player.setAudioSource(
        ConcatenatingAudioSource(children: children),
        initialIndex: 0,
        preload: false,
      );
      if (!_wired) {
        _wired = true;
        player.currentIndexStream.listen((i) {
          if (i != null && i != index) _onIndex(i);
        });
        player.playerStateStream.listen((s) {
          playing = s.playing;
          notifyListeners();
          _pushWidget();
        });
      }
      loading = false;
      notifyListeners();
      await _onIndex(0, force: true);
    } catch (_) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _onIndex(int i, {bool force = false}) async {
    if (i == index && !force) return;
    direction = i >= index ? 1 : -1;
    index = i;
    focus = i;
    notifyListeners();
    await _loadArt(i);
  }

  Future<void> _loadArt(int i) async {
    final token = ++_artToken;
    final s = songs[i];
    Uint8List? bytes;
    try {
      bytes = await query.queryArtwork(
        s.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 600,
        quality: 90,
      );
    } catch (_) {}
    if (token != _artToken) return;
    if (bytes != null && bytes.isEmpty) bytes = null;
    art = bytes;
    color = (bytes == null ? null : await dominantColor(bytes)) ??
        fallbackColor(s.id);
    if (token != _artToken) return;
    await _writeWidgetArt(bytes);
    notifyListeners();
    _pushWidget();
  }

  Future<void> _writeWidgetArt(Uint8List? bytes) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/widget_art.jpg');
      if (bytes == null) {
        if (await f.exists()) await f.delete();
        _widgetArtPath = '';
      } else {
        await f.writeAsBytes(bytes, flush: true);
        _widgetArtPath = f.path;
      }
    } catch (_) {
      _widgetArtPath = '';
    }
  }

  Future<void> _pushWidget() async {
    final s = current;
    if (s == null) return;
    try {
      await HomeWidget.saveWidgetData<String>('title', s.title);
      await HomeWidget.saveWidgetData<String>('artist', artistOf(s));
      await HomeWidget.saveWidgetData<bool>('playing', playing);
      await HomeWidget.saveWidgetData<String>('art', _widgetArtPath);
      await HomeWidget.updateWidget(androidName: 'AuraWidgetProvider');
    } catch (_) {}
  }

  // ---- actions ----
  Future<void> playAt(int i) async {
    await player.seek(Duration.zero, index: i);
    await player.play();
  }

  Future<void> toggle() async =>
      player.playing ? await player.pause() : await player.play();

  Future<void> next() async => player.seekToNext();

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    await player.setShuffleModeEnabled(shuffle);
    if (shuffle) await player.shuffle();
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    loop = switch (loop) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(loop);
    notifyListeners();
  }

  void setFocus(int i) {
    if (i == focus) return;
    focus = i;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
