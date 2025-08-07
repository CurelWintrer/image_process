import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/user_session.dart';
import 'package:path/path.dart' as path;



// 服务类封装所有批量操作方法
class ImageBatchService {


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
    String? path,
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
          selectedPath: path,
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
    String? selectedPath,
  }) async {
    // Windows环境具体实现...
    // 实现代码结构与原_downloadImagesForWindows相同
    // 需要将原方法中的state更新改为通过回调处理
    
    selectedPath ??= await FilePicker.platform.getDirectoryPath();
    if (selectedPath == null) {
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
        final filePath = path.join(selectedPath, image.imgName);

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
                Text('$resultMsg\n存储位置: $selectedPath'),
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
                      selectedPath!.replaceAll('/', '\\'),
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
}

