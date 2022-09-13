import 'dart:io';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:videoplayer/flick_video/video_native_player.dart';
import 'package:videoplayer/flick_video/video_state.dart';

class FlickVideoControlsPage extends StatefulWidget {
  const FlickVideoControlsPage({
    Key? key,
    this.controls,
    this.player,
    this.valueNotifier,
    this.lockedValueNotifier,
    this.percentageWidget,
    this.iconWidgetList,
    this.videoFit = BoxFit.cover,
    this.showPlayerControls,
    this.flickManager,
    this.onlyShowLock,
    this.playerLoadingFallback = const Center(
      child: CircularProgressIndicator(),
    ),
    this.playerErrorFallback = const Center(
      child: Icon(
        Icons.error,
        color: Colors.white,
      ),
    ),
    this.backgroundColor = Colors.black,
    this.iconThemeData = const IconThemeData(
      color: Colors.white,
      size: 20,
    ),
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
    ),
    this.aspectRatioWhenLoading = 16 / 9,
    this.willVideoPlayerControllerChange = true,
    this.closedCaptionTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
    ),
  }) : super(key: key);

  final Widget? controls;

  final Widget playerLoadingFallback;

  final Widget playerErrorFallback;
  final Widget Function({Widget? child})? player;
  final Widget? percentageWidget;

  final BoxFit videoFit;
  final Color backgroundColor;
  final ValueNotifier? valueNotifier;
  final ValueNotifier? lockedValueNotifier;
  final TextStyle textStyle;
  final TextStyle closedCaptionTextStyle;
  final IconThemeData iconThemeData;
  final double aspectRatioWhenLoading;
  final bool willVideoPlayerControllerChange;
  final bool? showPlayerControls;
  get videoPlayerController => null;
  final List<Widget>? iconWidgetList;
  final FlickManager? flickManager;
  final bool? onlyShowLock;
  @override
  FlickVideoControlsPageState createState() => FlickVideoControlsPageState();
}

class FlickVideoControlsPageState extends State<FlickVideoControlsPage> {
  VideoPlayerController? _videoPlayerController;
  bool locked = false;
  bool onlyShowLock = false;
  bool showPlayerControls = true;
  double _fullDx = 0;
  double _fullDy = 0;
  final GlobalKey _fullScreenKey = GlobalKey();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.lockedValueNotifier != null) {
      widget.lockedValueNotifier!.addListener(lockedListener);
    }
    if (widget.flickManager != null) {
      widget.flickManager!.flickDisplayManager!.addListener(showPlayerListener);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    if (widget.lockedValueNotifier != null) {
      widget.lockedValueNotifier!.removeListener(lockedListener);
    }
    if (widget.flickManager != null) {
      widget.flickManager!.flickDisplayManager!
          .removeListener(showPlayerListener);
    }
  }

  void lockedListener() {
    onlyShowLock = widget.lockedValueNotifier!.value;
    setState(() {});
  }

  void showPlayerListener() {
    showPlayerControls =
        widget.flickManager!.flickDisplayManager!.showPlayerControls;
    setState(() {});
  }

  getFullScreenPosition() {
    RenderBox? box =
        _fullScreenKey.currentContext?.findAncestorRenderObjectOfType();
    Offset offset = box!.localToGlobal(Offset.zero);
    _fullDx = offset.dx;
    _fullDy = offset.dy;
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    VideoPlayerController? newController =
        Provider.of<FlickVideoManager>(context).videoPlayerController;
    if ((widget.willVideoPlayerControllerChange &&
            _videoPlayerController != newController) ||
        _videoPlayerController == null) {
      _videoPlayerController = newController;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    FlickControlManager controlManager =
        Provider.of<FlickControlManager>(context);
    bool _showVideoCaption = controlManager.isSub;
    return IconTheme(
      data: widget.iconThemeData,
      child: LayoutBuilder(builder: (context, size) {
        return Container(
          color: widget.backgroundColor,
          child: DefaultTextStyle(
            style: widget.textStyle,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      _videoPlayerController!.closedCaptionFile != null &&
                              _showVideoCaption
                          ? Positioned(
                              bottom: 5,
                              child: Transform.scale(
                                scale: 0.7,
                                child: ClosedCaption(
                                    textStyle: widget.closedCaptionTextStyle,
                                    text: _videoPlayerController!
                                        .value.caption.text),
                              ),
                            )
                          : SizedBox(),
                      if (_videoPlayerController?.value.hasError == false &&
                          _videoPlayerController?.value.isInitialized == false)
                        widget.playerLoadingFallback,
                      if (_videoPlayerController?.value.hasError == true)
                        widget.playerErrorFallback,
                      if (widget.player != null)
                        widget.player!(
                            child: Stack(
                          children: [
                            VideoNativePlayer(
                              videoPlayerController: _videoPlayerController,
                              fit: BoxFit.contain,
                              aspectRatioWhenLoading:
                                  widget.aspectRatioWhenLoading,
                            ),
                            widget.controls ?? Container(),
                            if (!locked)
                              IgnorePointer(
                                ignoring: !showPlayerControls,
                                child: AnimatedOpacity(
                                  opacity: showPlayerControls || onlyShowLock
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(milliseconds: 250),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        locked = !locked;
                                        if (locked) {
                                          widget.flickManager!
                                              .flickDisplayManager!
                                              .hidePlayerControls();
                                          getFullScreenPosition();
                                          onlyShowLock = true;
                                          widget.lockedValueNotifier!.value =
                                              true;
                                        } else {
                                          widget.flickManager!
                                              .flickDisplayManager!
                                              .handleShowPlayerControls();
                                        }
                                        setState(() {});
                                      },
                                      icon: Container(
                                        key: _fullScreenKey,
                                        child: const Icon(
                                          Icons.lock_open_outlined,
                                          color: Colors.grey,
                                          size: 25,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 30,
                              left: 10,
                              child: IgnorePointer(
                                ignoring: !showPlayerControls,
                                child: AnimatedOpacity(
                                  opacity: showPlayerControls ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 250),
                                  child: IconButton(
                                      onPressed: () {
                                        if (VideoState.isFullScreen) {
                                          widget.flickManager!
                                              .flickDisplayManager!
                                              .hidePlayerControls();
                                          AutoOrientation.portraitAutoMode();
                                          if (Platform.isAndroid) {
                                            ///关闭状态栏，与底部虚拟操作按钮
                                            SystemChrome.setEnabledSystemUIMode(
                                                SystemUiMode.manual,
                                                overlays:
                                                    SystemUiOverlay.values);
                                          }
                                          VideoState.isFullScreen = false;
                                        } else {
                                          Navigator.pop(context);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.arrow_back_ios,
                                        size: 30,
                                        color: Colors.white,
                                      )),
                                ),
                              ),
                            ),
                            widget.percentageWidget ?? Container(),
                          ],
                        )),
                    ],
                  ),
                ),
                if (locked)
                  Positioned.fill(
                    child: GestureDetector(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: const Color(0x00000000),
                        alignment: Alignment.topCenter,
                        child: Stack(
                          children: [
                            Positioned(
                              left: _fullDx,
                              top: _fullDy,
                              child: IgnorePointer(
                                ignoring: !onlyShowLock,
                                child: AnimatedOpacity(
                                  opacity: showPlayerControls || onlyShowLock
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(milliseconds: 250),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        locked = !locked;
                                        widget
                                            .flickManager!.flickDisplayManager!
                                            .handleShowPlayerControls();
                                        widget.valueNotifier!.value = false;
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.lock_outlined,
                                        color: Colors.grey,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      onTap: () {
                        onlyShowLock = !onlyShowLock;
                        widget.lockedValueNotifier!.value = onlyShowLock;
                        setState(() {});
                      },
                    ),
                  )
              ],
            ),
          ),
        );
      }),
    );
  }
}
