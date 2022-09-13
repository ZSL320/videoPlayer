import 'package:flutter/foundation.dart';
import 'package:stack_trace/stack_trace.dart';

// 将 StackTrace 对象转换成 Chain 对象
// 当然，这里也可以直接用 Chain.current();
void logPrintUtil({dynamic msg}) {
  if (kReleaseMode) return;
  final chain = Chain.forTrace(StackTrace.current);
// 拿出其中一条信息
  final frames = chain.toTrace().frames;
  final frame = frames[1];
// 打印
  print("所在文件：${frame.uri} 所在行 ${frame.line} 所在列 ${frame.column}");
  print("打印日志：$msg");
}
// 打印结果
// flutter: 所在文件：package:flutterlog/main.dart 所在行 55 所在列 23
