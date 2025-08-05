import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/tools/GetCaption.dart';
import 'package:image_process/user_session.dart';
import 'package:path/path.dart' as path;



// 服务类封装所有批量操作方法
class ImageBatchService {
  static final _token =UserSession().token??'';
  static final _baseUrl=UserSession().baseUrl??'';

  // 通用工具方法：显示SnackBar
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --------------- 批量下载核心方法 ---------------
  static Future<void> downloadImages({
    required BuildContext context,
    required List<ImageModel> selectedImages,
  }) async {
    if (selectedImages.isEmpty) {
      _showSnackBar(context, '请先选择要下载的图片');
      return;
    }

    try {
      if (kIsWeb) {
        // Web环境处理...
      } else if (Platform.isWindows) {
        await _downloadForWindows(
          context: context,
          selectedImages: selectedImages,
        );
      } else {
        throw Exception('当前平台不支持批量下载');
      }
    } catch (e) {
      _showSnackBar(context, '批量下载失败: ${e.toString()}');
    }
  }

  static Future<void> _downloadForWindows({
    required BuildContext context,
    required List<ImageModel> selectedImages,
  }) async {
    // Windows环境具体实现...
    // 实现代码结构与原_downloadImagesForWindows相同
    // 需要将原方法中的state更新改为通过回调处理
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      _showSnackBar(context,'已取消选择文件夹');
      return;
    }

    // 2. 显示进度对话框
    bool downloadCancelled = false;
    List<Map<String, dynamic>> errors = []; // 存储错误信息
    int successCount = 0;

    // 进度对话框状态控制
    bool isDialogOpen = false;
    void Function(void Function())? updateDialogState;

    void closeProgressDialog() {
      if (isDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        isDialogOpen = true;
        return StatefulBuilder(
          builder: (context, setState) {
            updateDialogState = setState; // 保存状态更新函数
            return AlertDialog(
              title: Text('批量下载中'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value:
                        (successCount + errors.length) / selectedImages.length,
                    minHeight: 8,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '已处理 ${successCount + errors.length}/${selectedImages.length} 张图片',
                  ),
                  if (errors.isNotEmpty) SizedBox(height: 8),
                  if (errors.isNotEmpty)
                    Text(
                      '失败: ${errors.length} 张',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    downloadCancelled = true;
                    closeProgressDialog();
                  },
                  child: Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      // 3. 下载图片到选定文件夹（带错误处理）
      for (int i = 0; i < selectedImages.length; i++) {
        if (downloadCancelled) break;

        final image = selectedImages[i];
        final imageUrl = '${UserSession().baseUrl}/img/${image.imgPath}';
        final filePath = path.join(selectedDirectory, image.imgName);

        try {
          // 尝试下载文件
          final response = await http.get(Uri.parse(imageUrl));

          if (response.statusCode != 200) {
            // 记录404或其他错误
            errors.add({
              'name': image.imgName,
              'error': 'HTTP ${response.statusCode}',
            });
            continue; // 跳过当前文件
          }

          // 保存有效文件
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          successCount++;
        } catch (e) {
          // 捕获其他错误（如网络问题）
          errors.add({'name': image.imgName, 'error': e.toString()});
        } finally {
          // 更新进度显示
          if (updateDialogState != null) {
            updateDialogState!(() {});
          }
          await Future.delayed(Duration(milliseconds: 50)); // 避免UI阻塞
        }
      }

      // 4. 关闭进度对话框
      closeProgressDialog();

      // 5. 显示结果汇总
      if (downloadCancelled) {
        _showSnackBar(context,'批量下载已取消');
      } else {

        // 构建结果消息
        String resultMsg = '成功下载 $successCount 张图片';
        if (errors.isNotEmpty) {
          resultMsg += ', ${errors.length} 张下载失败';
        }

        // 显示结果弹窗
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(errors.isEmpty ? '下载完成' : '下载完成（有错误）'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$resultMsg\n存储位置: $selectedDirectory'),
                if (errors.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text('失败列表:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: SingleChildScrollView(
                      child: Column(
                        children: errors
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e['name'],
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      e['error'],
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (errors.isNotEmpty)
                TextButton(
                  child: Text('复制错误'),
                  onPressed: () {
                    final errorText = errors
                        .map((e) => '${e['name']}: ${e['error']}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: errorText));
                    _showSnackBar(context,'错误列表已复制');
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('关闭'),
              ),
              if (successCount > 0)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Process.run('explorer', [
                      selectedDirectory.replaceAll('/', '\\'),
                    ]);
                  },
                  child: Text('打开文件夹'),
                ),
            ],
          ),
        );

        // 显示底部通知
        _showSnackBar(context,resultMsg);
      }
    } catch (e) {
      closeProgressDialog();
      _showSnackBar(context,'批量下载失败: ${e.toString()}');
    }
  }

  // --------------- 批量更新描述核心方法 ---------------
  static Future<void> batchUpdateCaptions({
    required BuildContext context,
    required List<ImageModel> selectedImages,
    required Function(ImageUpdateResult) onImageUpdated, // 修改回调类型
  }) async {
    if (selectedImages.isEmpty) {
      _showSnackBar(context, '请先选择要更新的图片');
      return;
    }
  }

  static void _isolateCaptionUpdate(Map<String, dynamic> initData) {
    // 隔离区任务处理代码...
    final token = initData['token'] as String;
    final baseUrl = initData['baseUrl'] as String;
    final mainSendPort = initData['mainSendPort'] as SendPort;
    final resultSendPort = initData['resultSendPort'] as SendPort;

    // 创建隔离区自己的接收端口
    final isolatePort = ReceivePort();

    // 发送隔离区的SendPort给主isolate
    mainSendPort.send(isolatePort.sendPort);

    // 监听来自主isolate的任务
    isolatePort.listen((message) async {
      if (message['type'] == 'tasks') {
        final imagesJson = message['images'] as List<dynamic>;
        final images = imagesJson
            .map((json) => ImageModel.fromJson(json))
            .toList();

        for (var image in images) {
          try {
            // 1. 下载图片
            final imgUrl = '$baseUrl/img/${image.imgPath}';
            final base64Image =
                await ImageService.downloadImageAndConvertToBase64(imgUrl);

            // 2. 调用AI更新描述 - 使用ImageService的新方法
            final aiResponse = await ImageService.getImageCaptionFromAI(
              base64Image,
              image,
            );
            final newCaption = aiResponse.content;

            // 3. 更新数据库
            await ImageService.updateImageCaption(
              imageID: image.imageID,
              newCaption: newCaption,
            );

            // 发送成功消息
            resultSendPort.send({
              'status': 'success',
              'imageName': image.imgName,
              'message': newCaption,
            });
          } catch (e) {
            // 发送错误消息
            resultSendPort.send({
              'status': 'error',
              'imageName': image.imgName,
              'message': e.toString(),
            });
          }
        }
      }
    });
  }

  // --------------- 批量更新状态核心方法 ---------------
  static Future<void> batchUpdateStates({
    required BuildContext context,
    required String baseUrl,
    required String token,
    required List<ImageModel> selectedImages,
    required int newState,
    required Function(int, int) onStateUpdated, // 状态更新回调 (imageID, newState)
  }) async {
    // 实现代码结构与原_setImagesState相同
    // 通过onStateUpdated回调通知更新
  }
}



// 更新结果数据模型
class ImageUpdateResult {
  final int imageID;
  final String imgName;
  final UpdateStatus status;
  final String error;
  final String newCaption;

  ImageUpdateResult({
    required this.imageID,
    required this.imgName,
    required this.status,
    this.error = '',
    this.newCaption = '',
  });
}

enum UpdateStatus { success, failed }
