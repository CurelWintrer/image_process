import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_process/user_session.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;

class UploadHelper {
  static String baseUrl=UserSession().baseUrl;
  static String jwtToken=UserSession().token??'';
  /// 打开文件选择器并上传（适配所有平台）
  static Future<Map<String, dynamic>?> pickAndUpload({
    required BuildContext context,
    required int imageID,
  }) async {
    try {
      if (kIsWeb) {
        return await _pickAndUploadWeb(
          context: context,
          imageID: imageID,
        );
      } else {
        return await _pickAndUploadDesktop(
          context: context,
          imageID: imageID,
        );
      }
    } catch (e) {
      _showErrorSnackBar(context, '选择文件失败: ${e.toString()}');
      return null;
    }
  }

    
  /// Web端选择文件并上传
static Future<Map<String, dynamic>?> _pickAndUploadWeb({
  required BuildContext context,
  required int imageID,
}) async {
  final completer = Completer<html.File?>();
  final fileInput = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  fileInput.onChange.listen((e) {
    final files = fileInput.files;
    if (files != null && files.isNotEmpty) {
      completer.complete(files[0]);
    } else {
      completer.complete(null);
    }
  });

  fileInput.click();

  final webFile = await completer.future;
  if (webFile == null) return null;

  return await _uploadForWeb(
    imageID: imageID,
    context: context,
    webFile: webFile,
    completer: Completer<void>(),
  );
}

/// 桌面端选择文件并上传
static Future<Map<String, dynamic>?> _pickAndUploadDesktop({
  required BuildContext context,
  required int imageID,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );

  if (result != null && result.files.isNotEmpty) {
    final filePath = result.files.single.path;
    if (filePath != null) {
      return await _uploadForDesktop(
        context: context,
        imageID: imageID,
        filePath: filePath,
        completer: Completer<void>(),
      );
    }
  }
  return null;
}

  /// 上传图片方法（适配Web和桌面）
  static Future<void> uploadImage({
    required BuildContext context,
    required int imageID,
    required dynamic imageFile,
    String? desktopImagePath,
  }) async {
    try {
      // 统一处理加载状态
      final completer = Completer<void>();
      _showLoadingDialog(context, '正在上传图片...', completer);

      if (kIsWeb) {
        await _uploadForWeb(
          context: context,
          imageID: imageID,
          webFile: imageFile as html.File,
          completer: completer,
        );
      } else {
        await _uploadForDesktop(
          context: context,
          imageID: imageID,
          filePath: desktopImagePath ?? (imageFile as File).path,
          completer: completer,
        );
      }
    } catch (e) {
      // Navigator.of(context, rootNavigator: true).pop(); // 关闭加载对话框
      _showErrorSnackBar(context, '上传失败: ${e.toString()}');
      rethrow;
    }
  }

  /// Web端上传实现
  static Future<Map<String, dynamic>> _uploadForWeb({
    required BuildContext context,
    required int imageID,
    required html.File webFile,
    required Completer<void> completer,
  }) async {
    try {
      // 创建FormData
      final formData = html.FormData();
      formData.appendBlob('image', await webFile.slice(), webFile.name);
      formData.append('imageID', imageID.toString());

      // 使用Fetch API发送请求
      final response = await html.HttpRequest.request(
        '$baseUrl/api/image/upload',
        method: 'POST',
        requestHeaders: {'Authorization': 'Bearer $jwtToken'},
        sendData: formData,
      );

      // 检查响应状态码（添加空安全处理）
      final statusCode = response.status ?? 0; // 如果为null则默认0
      final responseText = response.responseText ?? ''; // 如果为null则默认空字符串

      if (statusCode != 200) {
        throw _handleErrorResponse(statusCode, responseText);
      }

      final result = jsonDecode(responseText);
      print(result);
      _showSuccessSnackBar(context, result['message'] ?? '上传成功');
      // 返回上传结果
      return {
        'message': result['message'],
        'imageID': result['imageID'],
        'md5': result['md5'],
        'fileName': result['fileName'],
        'imgPath': result['imgPath'],
      };
    } catch (e) {
      _showErrorSnackBar(context, '上传失败: ${e.toString()}');
      rethrow;
    } finally {
      completer.complete();
    }
  }

 

  /// 桌面端上传实现
  static Future<Map<String, dynamic>> _uploadForDesktop({
    required BuildContext context,
    required int imageID,
    required String filePath,
    required Completer<void> completer,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $jwtToken';

      // 添加图片文件
      final file = File(filePath);
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      final fileStream = http.ByteStream(file.openRead());
      final length = await file.length();

      request.files.add(
        http.MultipartFile(
          'image',
          fileStream,
          length,
          filename: path.basename(filePath),
          contentType: MediaType.parse(mimeType),
        ),
      );

      // 添加imageID字段
      request.fields['imageID'] = imageID.toString();

      // 发送请求
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print(responseBody);

      if (response.statusCode != 200) {
        throw _handleErrorResponse(response.statusCode, responseBody);
      }

      final result = jsonDecode(responseBody);
      _showSuccessSnackBar(context, result['message'] ?? '上传成功');
      // 返回上传结果
      return {
        'message': result['message'],
        'imageID': result['imageID'],
        'md5': result['md5'],
        'fileName': result['fileName'],
        'imgPath': result['imgPath'],
      };
    } finally {
      completer.complete();
    }
  }

  
  /// 错误处理
  static Exception _handleErrorResponse(int statusCode, String body) {
    final messages = {
      400: '未上传图片文件',
      401: '未授权或token无效',
      404: '未找到对应的图片记录',
      500: '服务器内部错误',
    };

    print(body);

    try {
      final error = jsonDecode(body);
      return Exception(error['message'] ?? messages[statusCode] ?? '上传失败');
    } catch (_) {
      return Exception(messages[statusCode] ?? 'HTTP错误: $statusCode');
    }
  }

  /// 显示加载对话框
  static void _showLoadingDialog(
    BuildContext context,
    String message,
    Completer<void> completer,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );

    completer.future.then((_) {
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  /// 显示成功提示
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 显示错误提示
  static void _showErrorSnackBar(BuildContext context, String message) {
    print(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
