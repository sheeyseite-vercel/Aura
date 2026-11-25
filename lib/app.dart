import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'controller.dart';

const _shuffleOn = Color(0xFFFFD84D);

String fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

Color _mix(Color c, double blackAmount) =>
    Color.lerp(c, Colors.black, blackAmount)!;

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8A3D),
          brightness: Brightness.dark,
        ),
      ),
      home: const Shell(),
    );
  }
}

// ---------------------------------------------------------------- building blocks

class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key, required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, _mix(color, 0.55), _mix(color, 0.88)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.9),
                  radius: 1.0,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(12),
    this.alpha = 0.14,
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: alpha),
            borderRadius: br,
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.song, required this.size, this.radius = 20});
  final SongModel song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hue = (song.id * 47 % 360).toDouble();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSVColor.fromAHSV(1, hue, 0.55, 0.95).toColor(),
            HSVColor.fromAHSV(1, (hue + 40) % 360, 0.8, 0.45).toColor(),
          ],
        ),
      ),
      child: Icon(Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.85), size: size * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: QueryArtworkWidget(
          id: song.id,
          type: ArtworkType.AUDIO,
          size: 600,
          quality: 90,
          artworkWidth: size,
          artworkHeight: size,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          nullArtworkWidget: placeholder,
        ),
      ),
    );
  }
}

class EqBars extends StatefulWidget {
  const EqBars({super.key, required this.active, this.color = Colors.white});
  final bool active;
  final Color color;

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(EqBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final h = widget.active
                ? 4 + 14 * (0.5 + 0.5 * math.sin(2 * math.pi * (_c.value + i * 0.23)))
                : 4.0;
            return Container(
              width: 3.5,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, required this.playing, required this.onTap, this.size = 68, required this.iconColor});
  final bool playing;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              size: size * 0.55,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shell

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final PlayerController c = PlayerController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    c.init();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _openNowPlaying() {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => NowPlayingPage(c: c),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget body;
        if (c.loading) {
          body = const Center(child: CircularProgressIndicator(color: Colors.white));
        } else if (c.denied) {
          body = _Message(
            icon: Icons.lock_outline_rounded,
            text: 'Aura needs permission to read the music on your phone.',
            button: 'Allow access',
            onTap: c.init,
          );
        } else if (c.songs.isEmpty) {
          body = _Message(
            icon: Icons.music_off_rounded,
            text: 'No music found on this phone.',
            button: 'Scan again',
            onTap: c.init,
          );
        } else {
          body = AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: tab == 0
                ? HomePage(key: const ValueKey('home'), c: c)
                : LibraryPage(key: const ValueKey('lib'), c: c),
          );
        }
        return Scaffold(
          body: AuraBackground(
            color: c.color,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(child: body),
                  if (c.songs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: MiniPlayer(c: c, onOpen: _openNowPlaying),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 40, 12),
                    child: Glass(
                      radius: 30,
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          _NavItem(
                            icon: Icons.album_rounded,
                            label: 'Home',
                            selected: tab == 0,
                            onTap: () => setState(() => tab = 0),
                          ),
                          _NavItem(
                            icon: Icons.library_music_rounded,
                            label: 'Songs',
                            selected: tab == 1,
                            onTap: () => setState(() => tab = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.button, required this.onTap});
  final IconData icon;
  final String text;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black87),
              child: Text(button),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- mini player

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.c, required this.onOpen});
  final PlayerController c;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = c.current!;
    final total = (s.duration ?? 0).toDouble();
    return Glass(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: Cover(key: ValueKey(s.id), song: s, size: 46, radius: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: Offset(0.15 * c.direction, 0), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(s.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(artistOf(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: c.previous,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
              ),
              PlayPauseButton(
                playing: c.playing,
                onTap: c.toggle,
                size: 44,
                iconColor: _mix(c.color, 0.35),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: c.next,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StreamBuilder<Duration>(
            stream: c.player.positionStream,
            builder: (context, snap) {
              final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble();
              return ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: total > 0 ? (pos / total).clamp(0.0, 1.0).toDouble() : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- home (3D carousel)

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.c});
  final PlayerController c;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController pc =
      PageController(viewportFraction: 0.66, initialPage: widget.c.index);
  late int _last = widget.c.index;

  PlayerController get c => widget.c;

  @override
  void initState() {
    super.initState();
    c.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (c.index != _last) {
      _last = c.index;
      if (pc.hasClients && (pc.page?.round() ?? c.index) != c.index) {
        pc.animateToPage(c.index,
            duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    c.removeListener(_onCtrl);
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final focusSong = c.songs[c.focus.clamp(0, c.songs.length - 1)];
        final focusIsCurrent = c.focus == c.index;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your library',
                          style: TextStyle(
                              fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                      const Text('Aura',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                  const Spacer(),
                  Glass(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('${c.songs.length} songs',
                        style: const TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 340,
              child: PageView.builder(
                controller: pc,
                itemCount: c.songs.length,
                onPageChanged: c.setFocus,
                itemBuilder: (context, i) {
                  return AnimatedBuilder(
                    animation: pc,
                    builder: (context, child) {
                      final page = (pc.hasClients && pc.position.haveDimensions)
                          ? (pc.page ?? c.index.toDouble())
                          : c.index.toDouble();
                      final d = (page - i).clamp(-1.0, 1.0).toDouble();
                      final m = Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(-d * 0.75)
                        ..scale(1 - d.abs() * 0.14);
                      return Opacity(
                        opacity: 1 - d.abs() * 0.35,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: m,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (i == c.focus) {
                          c.playAt(i);
                        } else {
                          pc.animateToPage(i,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic);
                        }
                      },
                      child: _AlbumCard(c: c, i: i),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: Padding(
                key: ValueKey(focusSong.id),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(focusSong.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(artistOf(focusSong),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            PlayPauseButton(
              playing: focusIsCurrent && c.playing,
              iconColor: _mix(c.color, 0.35),
              onTap: () => focusIsCurrent ? c.toggle() : c.playAt(c.focus),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.c, required this.i});
  final PlayerController c;
  final int i;

  @override
  Widget build(BuildContext context) {
    final s = c.songs[i];
    final isNow = i == c.index && c.playing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: LayoutBuilder(
        builder: (context, cons) {
          final side = math.min(cons.maxWidth - 20, cons.maxHeight - 20);
          return Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 36,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: Glass(
                radius: 32,
                padding: const EdgeInsets.all(10),
                alpha: 0.16,
                child: Stack(
                  children: [
                    Cover(song: s, size: side, radius: 24),
                    if (isNow)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const EqBars(active: true),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- library

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.c});
  final PlayerController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Text('Songs',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: c.songs.length,
                itemBuilder: (context, i) {
                  final s = c.songs[i];
                  final isCurrent = i == c.index;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => c.playAt(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 68,
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Cover(song: s, size: 48, radius: 14),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                        color: Colors.white)),
                                const SizedBox(height: 2),
                                Text(artistOf(s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.75))),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            EqBars(active: c.playing)
                          else
                            Text(fmt(Duration(milliseconds: s.duration ?? 0)),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
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

// ---------------------------------------------------------------- now playing

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key, required this.c});
  final PlayerController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.current!;
        return Scaffold(
          body: AuraBackground(
            color: c.color,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, cons) {
                  final cover = (cons.maxHeight * 0.36).clamp(180.0, 300.0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _CircleBtn(
                              icon: Icons.keyboard_arrow_down_rounded,
                              label: 'Close',
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('NOW PLAYING',
                                      style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 1.6,
                                          color: Colors.white.withValues(alpha: 0.8))),
                                  const SizedBox(height: 2),
                                  Text('${c.index + 1} of ${c.songs.length}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 44),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          height: cover + 12,
                          child: Center(
                            child: AnimatedScale(
                              scale: c.playing ? 1.0 : 0.88,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 550),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) {
                                  final incoming = child.key == ValueKey<int>(s.id);
                                  final dir = c.direction.toDouble();
                                  final begin =
                                      Offset(incoming ? dir * 0.5 : -dir * 0.5, 0);
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(begin: begin, end: Offset.zero)
                                          .animate(anim),
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: DecoratedBox(
                                  key: ValueKey<int>(s.id),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.color.withValues(alpha: 0.7),
                                        blurRadius: 60,
                                        spreadRadius: -8,
                                        offset: const Offset(0, 30),
                                      ),
                                    ],
                                  ),
                                  child: Cover(song: s, size: cover, radius: 40),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.3), end: Offset.zero)
                                  .animate(anim),
                              child: child,
                            ),
                          ),
                          child: SizedBox(
                            key: ValueKey(s.id),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(artistOf(s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withValues(alpha: 0.85))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Glass(
                          radius: 32,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            children: [
                              Seekbar(player: c.player, fallbackMs: s.duration ?? 0),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    tooltip: 'Shuffle',
                                    onPressed: c.toggleShuffle,
                                    icon: Icon(Icons.shuffle_rounded,
                                        size: 26,
                                        color: c.shuffle ? _shuffleOn : Colors.white),
                                  ),
                                  IconButton(
                                    tooltip: 'Previous',
                                    onPressed: c.previous,
                                    icon: const Icon(Icons.skip_previous_rounded,
                                        size: 38, color: Colors.white),
                                  ),
                                  PlayPauseButton(
                                    playing: c.playing,
                                    onTap: c.toggle,
                                    iconColor: _mix(c.color, 0.35),
                                  ),
                                  IconButton(
                                    tooltip: 'Next',
                                    onPressed: c.next,
                                    icon: const Icon(Icons.skip_next_rounded,
                                        size: 38, color: Colors.white),
                                  ),
                                  IconButton(
                                    tooltip: 'Repeat',
                                    onPressed: c.cycleLoop,
                                    icon: Icon(
                                      c.loop == LoopMode.one
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                      size: 26,
                                      color: c.loop == LoopMode.off
                                          ? Colors.white
                                          : _shuffleOn,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class Seekbar extends StatefulWidget {
  const Seekbar({super.key, required this.player, required this.fallbackMs});
  final AudioPlayer player;
  final int fallbackMs;

  @override
  State<Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<Seekbar> {
  double? dragging;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snap) {
        final total = (widget.player.duration?.inMilliseconds ?? widget.fallbackMs)
            .toDouble();
        final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble();
        final max = total > 0 ? total : 1.0;
        final value = (dragging ?? pos).clamp(0.0, max).toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                max: max,
                onChanged: (v) => setState(() => dragging = v),
                onChangeEnd: (v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => dragging = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt(Duration(milliseconds: value.round())),
                      style: const TextStyle(fontSize: 12, color: Colors.white)),
                  Text('-${fmt(Duration(milliseconds: (max - value).round()))}',
                      style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
