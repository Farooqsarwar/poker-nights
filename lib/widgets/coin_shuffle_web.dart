// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildCoinShuffleAnimation() {
  return const _CoinShuffleAnimationWeb();
}

class _CoinShuffleAnimationWeb extends StatefulWidget {
  const _CoinShuffleAnimationWeb();

  @override
  State<_CoinShuffleAnimationWeb> createState() => _CoinShuffleAnimationWebState();
}

class _CoinShuffleAnimationWebState extends State<_CoinShuffleAnimationWeb> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'coin-3d-iframe-${DateTime.now().millisecondsSinceEpoch}';
    
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = 'transparent'
        ..src = 'coin_3d.html',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
