import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:videoplayer/flick_video/video_state.dart';

class VideoPlayerFlickPortraitControls extends StatelessWidget {
  const VideoPlayerFlickPortraitControls({
    Key? key,
    this.iconSize = 20,
    this.fontSize = 12,
    this.progressBarSettings,
    required this.flickManager,
  }) : super(key: key);

  final double iconSize;
  final double fontSize;
  final FlickManager flickManager;
  final FlickProgressBarSettings? progressBarSettings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: FlickShowControlsAction(
            child: FlickSeekVideoAction(
              child: Center(
                child: FlickVideoBuffer(
                  child: FlickAutoHideChild(
                    showIfVideoNotInitialized: false,
                    child: FlickPlayToggle(
                      size: 30,
                      color: Colors.black,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: FlickAutoHideChild(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FlickVideoProgressBar(
                    flickProgressBarSettings: progressBarSettings,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      FlickPlayToggle(
                        size: iconSize,
                      ),
                      SizedBox(
                        width: iconSize / 2,
                      ),
                      FlickSoundToggle(
                        size: iconSize,
                      ),
                      SizedBox(
                        width: iconSize / 2,
                      ),
                      Row(
                        children: <Widget>[
                          FlickCurrentPosition(
                            fontSize: fontSize,
                          ),
                          FlickAutoHideChild(
                            child: Text(
                              ' / ',
                              style: TextStyle(
                                  color: Colors.white, fontSize: fontSize),
                            ),
                          ),
                          FlickTotalDuration(
                            fontSize: fontSize,
                          ),
                        ],
                      ),
                      Expanded(
                        child: Container(),
                      ),
                      FlickSubtitleToggle(
                        size: iconSize,
                      ),
                      SizedBox(
                        width: iconSize / 2,
                      ),
                      InkWell(
                        onTap: () {
                          VideoState.isFullScreen = true;
                          AutoOrientation.landscapeAutoMode();
                          flickManager.flickDisplayManager!
                              .hidePlayerControls();
                          // iOS13+???????????????????????????????????????????????????https://juejin.cn/post/7054063406579449863
                          if (Platform.isAndroid) {
                            ///?????????????????????????????????????????????
                            SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.manual,
                                overlays: []);
                          }
                        },
                        child: Icon(
                          Icons.fullscreen,
                          size: iconSize,
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
