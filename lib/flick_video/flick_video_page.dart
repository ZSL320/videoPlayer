import 'dart:async';
import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:brightness_volume/brightness_volume.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:flutter/material.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:videoplayer/flick_video/percent_widget.dart';
import 'package:videoplayer/flick_video/video_portrait_controls.dart';
import 'package:videoplayer/flick_video/video_state.dart';

import '../../utils/logUtil.dart';
import 'flickVideo_controls_page.dart';
import 'flick_port_control.dart';

class CommonVideoPlayer extends StatefulWidget {
  final String videoPath;
  const CommonVideoPlayer({Key? key, required this.videoPath})
      : super(key: key);

  @override
  _CommonVideoPlayerState createState() => _CommonVideoPlayerState();
}

class _CommonVideoPlayerState extends State<CommonVideoPlayer> {
  FlickManager? flickManager;
  double? aspectRatio;
  double _width = 0.0; // 组件宽度
  double _height = 0.0; // 组件高度
  late Offset _startPanOffset; //  滑动的起始位置
  late double _movePan; // 滑动的偏移量累计总和
  bool _brightnessOk = false; // 是否允许调节亮度
  bool _volumeOk = false; // 是否允许调节亮度
  double _brightnessValue = 0.0; // 设备当前的亮度
  double _volumeValue = 0.0; // 设备本身的音量
  Duration _positionValue = const Duration(seconds: 0); // 当前播放时间，以计算手势快进或快退
  late PercentWidget _percentageWidget; // 快退、快进、音量、亮度的百分比，手势操作时显示的widget
  bool showPlayerControls = true;
  ValueNotifier? valueNotifier = ValueNotifier(true);
  ValueNotifier? lockedNotifier = ValueNotifier(false);
  Timer? showPlayerTimer;
  Timer? playerTimer;
  Timer? showLockTimer;
  bool locked = false;
  bool onlyShowLock = false;

  @override
  void initState() {
    _percentageWidget = PercentWidget();
    super.initState();
    getVideoData();
    flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.network(widget.videoPath),
    );
    _setInit();
    flickManager!.flickControlManager!.addListener(playListener);
    flickManager!.flickDisplayManager!.addListener(listener);
    flickManager!.flickVideoManager!.addListener(videoManagerListener);
    valueNotifier!.addListener(valueListener);
    lockedNotifier!.addListener(lockedNotifierListener);
  }

  void lockedNotifierListener() {
    if (showLockTimer != null) {
      showLockTimer!.cancel();
    }
    if (lockedNotifier!.value) {
      showLockTimer = Timer(const Duration(seconds: 1), () {
        if (!onlyShowLock) {
          showLockTimer!.cancel();
        }
        onlyShowLock = false;
        lockedNotifier!.value = false;
        showLockTimer!.cancel();
      });
      setState(() {});
    }
  }

  void videoManagerListener() {
    if (flickManager!.flickVideoManager!.isVideoEnded) {
      locked = false;
    }
    setState(() {});
  }

  void playListener() {
    valueNotifier!.value = flickManager!.flickVideoManager!.isPlaying;
    setState(() {});
  }

  void listener() {
    showPlayerControls = flickManager!.flickDisplayManager!.showPlayerControls;
    if (showPlayerTimer != null) {
      showPlayerTimer!.cancel();
    }
    if (showPlayerControls) {
      showPlayerTimer = Timer(const Duration(seconds: 3), () {
        if (!flickManager!.flickDisplayManager!.showPlayerControls) {
          showPlayerTimer!.cancel();
        }
        flickManager!.flickDisplayManager!.hidePlayerControls();
        showPlayerTimer!.cancel();
      });
    }
    setState(() {});
  }

  void valueListener() {
    if (playerTimer != null) {
      playerTimer!.cancel();
    }
    if (!valueNotifier!.value) {
      playerTimer = Timer(const Duration(seconds: 3), () {
        if (flickManager!.flickVideoManager!.isPlaying) {
          playerTimer!.cancel();
        }
        flickManager!.flickDisplayManager!.hidePlayerControls();
        playerTimer!.cancel();
      });
    }
  }

  Future<void> getVideoData() async {
    await FFprobeKit.getMediaInformation(widget.videoPath)
        .then((session) async {
      final information = session.getMediaInformation();
      if (information != null) {
        logPrintUtil(msg: information.getAllProperties());
        aspectRatio = (information.getStreams()[0].getWidth()! /
                information.getStreams()[0].getHeight()!)
            .toDouble();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    flickManager!.flickDisplayManager!.removeListener(listener);
    flickManager!.flickControlManager!.removeListener(playListener);
    flickManager!.flickVideoManager!.removeListener(videoManagerListener);
    valueNotifier!.removeListener(valueListener);
    flickManager!.dispose();
    valueNotifier!.dispose();
    if (VideoState.isFullScreen) {
      AutoOrientation.portraitAutoMode();
      if (Platform.isAndroid) {
        ///关闭状态栏，与底部虚拟操作按钮
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: SystemUiOverlay.values);
      }
    }
    VideoState.isFullScreen = false;
    super.dispose();
  }

  void _setInit() async {
    _volumeValue = await getVolume();
    _brightnessValue = await getBrightness();
  }

  // 获取音量
  Future<double> getVolume() async {
    return await BVUtils.volume;
  }

  // 设置音量
  Future<void> setVolume(double volume) async {
    return await BVUtils.setVolume(volume);
  }

  // 获取亮度
  Future<double> getBrightness() async {
    return await BVUtils.brightness;
  }

  // 设置亮度
  Future<void> setBrightness(double brightness) async {
    return await BVUtils.setBrightness(brightness);
  }

  // 计算亮度百分比
  double _getBrightnessValue() {
    double value = double.parse(
        (_movePan / _height + _brightnessValue).toStringAsFixed(2));
    if (value >= 1.00) {
      value = 1.00;
    } else if (value <= 0.00) {
      value = 0.00;
    }
    return value;
  }

  // 重置手势
  void _resetPan() {
    _startPanOffset = const Offset(0, 0);
    _movePan = 0;
    _width = context.size!.width;
    _height = context.size!.height;
  }

  // 计算声音百分比
  double _getVolumeValue() {
    double value =
        double.parse((_movePan / _height + _volumeValue).toStringAsFixed(2));
    if (value >= 1.0) {
      value = 1.0;
    } else if (value <= 0.0) {
      value = 0.0;
    }
    return value;
  }

  // 计算播放进度百分比
  double _getSeekValue() {
    // 进度条百分控制
    double valueHorizontal =
        double.parse((_movePan / _width).toStringAsFixed(2));
    // 当前进度条百分比
    double currentValue = _positionValue.inMilliseconds /
        flickManager!
            .flickVideoManager!.videoPlayerValue!.duration.inMilliseconds;
    double value =
        double.parse((currentValue + valueHorizontal).toStringAsFixed(2));
    if (value >= 1.00) {
      value = 1.00;
    } else if (value <= 0.00) {
      value = 0.00;
    }
    return value;
  }

  // 简单处理下时间格式化mm:ss （超过1小时可自行处理hh:mm:ss）
  static String formatDuration(int second) {
    int min = second ~/ 60;
    int sec = second % 60;
    String minString = min < 10 ? "0$min" : min.toString();
    String secString = sec < 10 ? "0$sec" : sec.toString();
    return minString + ":" + secString;
  }

  void _onVerticalDragStart(DragStartDetails e) {
    _startPanOffset = const Offset(0, 0);
    _movePan = 0;
    _width = context.size!.width;
    _height = context.size!.height;
    _startPanOffset = e.globalPosition;
    if (_startPanOffset.dx < _width * 0.5) {
      // 左边调整亮度
      _brightnessOk = true;
    } else {
      // 右边调整声音
      _volumeOk = true;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // 累计计算偏移量(下滑减少百分比，上滑增加百分比)
    _movePan += (-details.delta.dy);
    if (_startPanOffset.dx < (_width / 2)) {
      if (_brightnessOk) {
        double b = _getBrightnessValue();
        _percentageWidget.percentageCallback("亮度：${(b * 100).toInt()}%");
        setBrightness(b);
      }
    } else {
      if (_volumeOk) {
        double v = _getVolumeValue();
        _percentageWidget.percentageCallback("音量：${(v * 100).toInt()}%");
        setVolume(v);
      }
    }
  }

  void _onHorizontalDragStart(DragStartDetails e) {
    _resetPan();
    _positionValue =
        flickManager!.flickVideoManager!.videoPlayerValue!.position;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails e) {
    _movePan += e.delta.dx;
    double value = _getSeekValue();

    String currentSecond = formatDuration((value *
            flickManager!
                .flickVideoManager!.videoPlayerValue!.duration.inSeconds)
        .toInt());
    if (_movePan >= 0) {
      _percentageWidget.percentageCallback("快进至：$currentSecond");
    } else {
      _percentageWidget.percentageCallback("快退至：$currentSecond");
    }
  }

  void _onVerticalDragEnd(_) {
    // 隐藏
    _percentageWidget.offstageCallback(true);
    if (_volumeOk) {
      _volumeValue = _getVolumeValue();
      _volumeOk = false;
    } else if (_brightnessOk) {
      _brightnessValue = _getBrightnessValue();
      _brightnessOk = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails e) {
    double value = _getSeekValue();
    int seek = (value *
            flickManager!
                .flickVideoManager!.videoPlayerValue!.duration.inMilliseconds)
        .toInt();
    flickManager!.flickControlManager!.seekTo(Duration(milliseconds: seek));
    _percentageWidget.offstageCallback(true);
  }

  @override
  Widget build(BuildContext context) {
    return player();
  }

  Widget Function({Widget? child}) _gestureDetector() {
    return ({Widget? child}) {
      return GestureDetector(
          onTap: () {
            if (showPlayerControls) {
              flickManager!.flickDisplayManager!.hidePlayerControls();
            } else {
              flickManager!.flickDisplayManager!.handleShowPlayerControls();
            }
          }, // 单击上下widget隐藏与显示
          onDoubleTap: () {
            if (flickManager!.flickVideoManager!.isPlaying) {
              flickManager!.flickControlManager!.pause();
            } else {
              flickManager!.flickControlManager!.play();
            }
          }, // 双击暂停、播放
          onVerticalDragStart: _onVerticalDragStart, // 根据起始位置。确定是调整亮度还是调整声音
          onVerticalDragUpdate: _onVerticalDragUpdate, // 一般在更新的时候，同步调整亮度或声音
          onVerticalDragEnd: _onVerticalDragEnd, // 结束后，隐藏百分比提示信息widget
          onHorizontalDragStart: _onHorizontalDragStart, // 手势跳转播放起始位置
          onHorizontalDragUpdate: _onHorizontalDragUpdate, // 根据手势更新快进或快退
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: child);
    };
  }

  Widget player() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        alignment: Alignment.center,
        child: FlickVideoPlayer(
          flickManager: flickManager!,
          preferredDeviceOrientationFullscreen: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight
          ],
          flickVideoWithControls: FlickVideoControlsPage(
            aspectRatioWhenLoading: aspectRatio ?? 1.0,
            player: _gestureDetector(),
            percentageWidget: _percentageWidget,
            flickManager: flickManager,
            valueNotifier: valueNotifier,
            lockedValueNotifier: lockedNotifier,
            controls: VideoState.isFullScreen
                ? VideoPortraitControls(
                    flickManager: flickManager!,
                  )
                : VideoPlayerFlickPortraitControls(
                    flickManager: flickManager!,
                  ),
          ),
        ),
      ),
    );
  }
}
