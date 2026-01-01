import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashAnimatedPage extends StatefulWidget {
  const SplashAnimatedPage({super.key, required this.dashboard});

  final Widget dashboard;

  @override
  State<SplashAnimatedPage> createState() => _SplashAnimatedPageState();
}

class _SplashAnimatedPageState extends State<SplashAnimatedPage>
    with TickerProviderStateMixin {
  late final AnimationController _capsuleCtrl;
  late final AnimationController _clockCtrl;
  late final AnimationController _revealCtrl;

  late final Animation<double> _capsuleY; // 0..1，映射到屏幕坐标
  late final Animation<double> _capsuleScale; // 胶囊轻微缩放增强“触地感”
  late final Animation<double> _clockOpacity; // 时钟淡入
  late final Animation<double> _clockScale; // 时钟微缩放出现
  late final Animation<double> _reveal; // 0..1 圆形遮罩半径比例

  bool _capsuleOpened = false;

  // 你可以按主题调整
  final Color _bg = const Color.fromARGB(255, 255, 255, 255); // 冷静深色背景
  final String _capsuleClosedAsset = 'assets/splash/capsule_closed.png';
  final String _capsuleOpenAsset = 'assets/splash/capsule_open.png';
  final String _clockGifAsset = 'assets/splash/clock.gif';

  @override
  void initState() {
    super.initState();

    // 1) 胶囊下落+反弹
    _capsuleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 下落：0 -> 1.0，反弹：1.0 -> 0.90 -> 0.97（一次回弹）
    _capsuleY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 76,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.80,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
    ]).animate(_capsuleCtrl);

    _capsuleScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
      // 触地瞬间轻微压缩
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
    ]).animate(_capsuleCtrl);

    // 2) 时钟出现（GIF 本身在旋转，不需要你再做旋转）
    _clockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _clockOpacity = CurvedAnimation(parent: _clockCtrl, curve: Curves.easeOut);

    _clockScale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _clockCtrl, curve: Curves.easeOutBack));

    // 3) 遮罩 reveal 进入 Dashboard
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _reveal = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeInOutCubic,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 胶囊落地+反弹
    await _capsuleCtrl.forward();

    if (!mounted) return;
    setState(() => _capsuleOpened = true);

    // 打开后时钟出现
    await _clockCtrl.forward();

    // 停留一小会（可选，让用户看清“可信时间”意象）
    await Future.delayed(const Duration(milliseconds: 250));

    // 遮罩进入 Dashboard
    await _revealCtrl.forward();

    // 动画完成后，替换页面栈（避免返回回到 splash）
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.dashboard,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _capsuleCtrl.dispose();
    _clockCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;

    // 胶囊大小：保证 48/64 下也清晰的逻辑在 icon 上做，这里动画用相对尺寸
    final capsuleW = math.min(size.width * 0.38, 180.0);
    final capsuleH = capsuleW;
    final clockSize = math.min(capsuleW * 1.25, size.width * 0.62);

    // 地面位置：屏幕底部以上 1/3 处（= 2/3 高度）
    final groundY = size.height * (2 / 3);

    // 根据 _capsuleY(0..1) 映射到屏幕：从顶部外侧落到 groundY
    double capsuleTop(double t) {
      final start = -capsuleH * 2.4; // 起始更高，竖屏更明显
      final end = groundY - capsuleH / 2; // 落点在地面附近
      return start + (end - start) * t;
    }

    // 时钟位置：以胶囊打开的位置为中心
    Offset clockCenter(double capTop) {
      final cx = size.width / 2;
      final cy = capTop + capsuleH * 0.50;
      return Offset(cx, cy);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Dashboard 在底层，等 reveal 的 clip 显示出来
          Positioned.fill(child: widget.dashboard),

          // 上层：splash 场景 + reveal
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _capsuleCtrl,
                _clockCtrl,
                _revealCtrl,
              ]),
              builder: (context, _) {
                final capTop = capsuleTop(_capsuleY.value);
                final center = clockCenter(capTop);

                // Reveal 半径：从时钟中心扩张到覆盖全屏
                final maxRadius = math.sqrt(
                  size.width * size.width + size.height * size.height,
                );
                final radius = maxRadius * _reveal.value;

                return Stack(
                  children: [
                    // Splash 场景（在 reveal 之前可见；reveal 期间用 clip 逐步露出 dashboard）
                    // 这里我们让 splash 作为“遮罩外”的内容：用 ClipPath 反向裁剪（简单做法：reveal 后直接看 dashboard）
                    // 为了实现“遮罩进入 dashboard”，我们这样做：
                    // 1) splash 作为前景整体显示
                    // 2) 使用 ClipPath 将 dashboard 以圆形区域露出（感觉像从时钟中心“打开到 dashboard”）
                    Positioned.fill(child: Container(color: _bg)),

                    // 胶囊
                    Positioned(
                      top: capTop,
                      left: (size.width - capsuleW) / 2,
                      child: Transform.scale(
                        scale: _capsuleScale.value,
                        child: Image.asset(
                          _capsuleOpened
                              ? _capsuleOpenAsset
                              : _capsuleClosedAsset,
                          width: capsuleW,
                          height: capsuleH,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),

                    // 时钟（打开后出现）
                    if (_capsuleOpened)
                      Positioned(
                        left: center.dx - clockSize / 2,
                        top: center.dy - clockSize / 2,
                        child: Opacity(
                          opacity: _clockOpacity.value,
                          child: Transform.scale(
                            scale: _clockScale.value,
                            child: Image.asset(
                              _clockGifAsset,
                              width: clockSize,
                              height: clockSize,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),

                    // 关键：以时钟中心为圆形 clip，将 dashboard “露出”
                    // 当 _reveal=0 时几乎不露出；_reveal=1 时全屏 dashboard
                    ClipPath(
                      clipper: _CircularRevealClipper(
                        center: center,
                        radius: radius,
                      ),
                      child: widget.dashboard,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  _CircularRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
