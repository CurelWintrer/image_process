import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/user_session.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class DownloadHelper {
static String baseUrl=UserSession().baseUrl;
  /// 下载图片方法（适配Windows和Web）
static Future<void> downloadImage({
  required BuildContext context,
  required String imgPath,
  required String imgName,
}) async {
  try {
    final imageUrl = '$baseUrl/img/$imgPath';
    
    if (kIsWeb) {
      await _downloadForWeb(context, imageUrl, imgName);
    } else {
      // 非Web环境
      if (Platform.isWindows) {
        await _downloadForWindows(context, imageUrl, imgName);
      } else {
        throw Exception('当前平台不支持下载功能');
      }
    }
    
    _showSnackBar(context, '图片下载成功');
  } catch (e) {
    print('下载错误: $e');
    _showSnackBar(context, '下载失败: ${e.toString().replaceAll('Unsupported operation: ', '')}');
  }
}

  /// Windows桌面端下载实现
  static Future<void> _downloadForWindows(
      BuildContext context, String imageUrl, String fileName) async {
    // 1. 打开文件夹选择器
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory == null) {
      throw Exception('用户取消了文件夹选择');
    }
    
    // 2. 显示下载进度对话框
    bool shouldOverwrite = false;
    final dialogContext = Navigator.of(context, rootNavigator: true).context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('正在下载'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在下载 $fileName...'),
          ],
        ),
      ),
    );
    
    try {
      // 3. 下载文件
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
      
      // 4. 保存文件
      final filePath = path.join(selectedDirectory, fileName);
      final file = File(filePath);
      
      // 检查文件是否已存在
      if (await file.exists()) {
        // 关闭进度对话框以便显示覆盖确认框
        Navigator.pop(dialogContext);
        
        shouldOverwrite = await _showOverwriteDialog(context, fileName) == true;
        
        if (!shouldOverwrite) return;
        
        // 重新显示进度对话框
        showDialog(
          context: dialogContext,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('正在下载'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载 $fileName...'),
              ],
            ),
          ),
        );
      }
      
      await file.writeAsBytes(response.bodyBytes);
      
      // 5. 关闭进度对话框
      Navigator.pop(dialogContext);
      
      // 6. 询问是否打开文件夹
      final openFolder = await _showOpenFolderDialog(context, filePath);
      
      if (openFolder == true) {
        await Process.run('explorer', [selectedDirectory]);
      }
    } catch (e) {
      // 确保关闭所有对话框
      Navigator.pop(dialogContext);
      rethrow;
    }
  }
  
  /// 显示覆盖文件确认对话框
  static Future<bool?> _showOverwriteDialog(BuildContext context, String fileName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('文件已存在'),
        content: Text('$fileName 已存在，是否覆盖？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('覆盖'),
          ),
        ],
      ),
    );
  }
  
  /// 显示打开文件夹对话框
  static Future<bool?> _showOpenFolderDialog(BuildContext context, String filePath) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('下载完成'),
        content: Text('文件已保存到: $filePath'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('关闭'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('打开文件夹'),
          ),
        ],
      ),
    );
  }

  /// Web端下载实现
  static Future<void> _downloadForWeb(
      BuildContext context, String imageUrl, String fileName) async {
    // 1. 显示下载提示
    _showSnackBar(context, '正在准备下载 $fileName...');
    
    try {
      // 2. 获取文件数据
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
      
      // 3. 创建Blob对象
      final blob = html.Blob([response.bodyBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // 4. 创建下载链接
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // 5. 触发下载
      html.document.body?.children.add(anchor);
      anchor.click();
      
      // 6. 清理
      Future.delayed(const Duration(seconds: 1), () {
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      rethrow;
    }
  }
  
  /// 显示SnackBar消息
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}