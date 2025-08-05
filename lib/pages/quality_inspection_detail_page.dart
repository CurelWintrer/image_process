import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:image_process/model/image_model.dart';
import 'package:image_process/tools/DownloadHelper.dart';
import 'package:image_process/tools/GetCaption.dart';
import 'package:image_process/tools/UploadHelper%20.dart';
import 'package:image_process/user_session.dart';

class QualityInspectionDetailPage extends StatefulWidget {
  final int taskId;

  const QualityInspectionDetailPage({super.key, required this.taskId});

  @override
  State<QualityInspectionDetailPage> createState() =>
      _QualityInspectionDetailPageState();
}

class _QualityInspectionDetailPageState
    extends State<QualityInspectionDetailPage> {
  late Future<Map<String, dynamic>> _taskData;
  ImageModel? _selectedImage;
  List<ImageModel> _images = [];
  Map<String, TextEditingController> _captionControllers = {};
  final String apiBaseUrl = UserSession().baseUrl;
  final String imgBasePath = '/img/';

  // 选择模式相关状态
  bool _isSelecting = false;
  Set<int> _selectedImageIds = Set<int>();
  // 缓存加载成功的图片URL
  final Set<String> _failedUrls = {};
  // 批量处理状态
  bool _isBatchProcessing = false;
  int _batchProgress = 0;
  int _batchSuccessCount = 0;
  int _batchErrorCount = 0;
  List<String> _batchErrors = [];

  @override
  void initState() {
    super.initState();
    _taskData = _fetchTaskData().then((data) {
      if (mounted)
        setState(() {
          _images = List<Map<String, dynamic>>.from(
            data['images'],
          ).map((json) => ImageModel.fromJson(json)).toList();
        });
      return data;
    });
  }

  Future<Map<String, dynamic>> _fetchTaskData() async {
    final token = UserSession().token;
    if (token == null) throw Exception('未找到认证token');

    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/check-tasks/${widget.taskId}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // 为每个图片初始化caption控制器
      for (var image in data['images']) {
        _captionControllers[image['imageID'].toString()] =
            TextEditingController(text: image['caption']);
      }
      return data;
    } else {
      throw Exception('获取任务详情失败: ${response.statusCode}');
    }
  }

  Future<void> _updateCaptionByhand(String newCaption, int imageID) async {
    await ImageService.updateImageCaption(
      token: UserSession().token ?? '',
      imageID: imageID,
      newCaption: newCaption,
    );
    // 4. 更新本地状态
    setState(() {
      _taskData = _fetchTaskData();
    });
    // 显示成功消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedImage?.chinaElementName}描述更新成功!')),
    );
  }

  @override
  void dispose() {
    // 清理所有控制器
    _captionControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // 切换选择模式
  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) {
        _selectedImageIds.clear();
      }
    });
  }

  Future<void> _setImageState(int imageID, int state) async {
    try {
      final respose = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "states": [
            {"imageID": imageID, "state": state},
          ],
        }),
      );
      print(respose.body);
      if (respose.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('修改成功')));
      }
      setState(() {
        _images = _images.map((img) {
          if (img.imageID == imageID) {
            return img.copyWith(state: state);
          }
          return img;
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('修改失败')));
    }
  }

  // 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      // 包含废弃图片在内
      if (_selectedImageIds.length == _images.length) {
        _selectedImageIds.clear();
      } else {
        _selectedImageIds = Set.from(_images.map((img) => img.imageID));
      }
    });
  }

  // 单个图片点击处理
  void _handleImageTap(int imageId) {
    // 移除废弃状态的检查，允许所有图片都可以选择
    if (_isSelecting) {
      setState(() {
        if (_selectedImageIds.contains(imageId)) {
          _selectedImageIds.remove(imageId);
        } else {
          _selectedImageIds.add(imageId);
        }
      });
    } else {
      setState(() {
        _selectedImage = _images.firstWhere((img) => img.imageID == imageId);
      });
    }
  }

  // 批量AI生成Caption
  Future<void> _batchAiGenerateCaptions() async {
    // 确定选中的图片ID
    if (_selectedImageIds.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一张图片')));
      return;
    }
    final imageIds = _selectedImageIds.isNotEmpty
        ? _selectedImageIds
        : {_selectedImage!.imageID};

    // 获取实际图片对象
    final selectedImages = _images
        .where((img) => imageIds.contains(img.imageID))
        .toList();

    // 进度对话框控制变量
    bool isDialogOpen = false;
    bool processCancelled = false;
    int processedCount = 0;
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];
    Function(void Function())? updateDialogState;

    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        isDialogOpen = true;
        return StatefulBuilder(
          builder: (context, setState) {
            updateDialogState = setState;
            return AlertDialog(
              title: const Text('AI生成描述中'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: processedCount / selectedImages.length,
                  ),
                  const SizedBox(height: 16),
                  Text('进度: $processedCount/${selectedImages.length}'),
                  Text('成功: $successCount, 失败: $errorCount'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('错误列表:'),
                    ...errors
                        .take(3)
                        .map(
                          (e) => Text(
                            e,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    processCancelled = true;
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      // 1. 准备隔离区
      final isolatePorts = <SendPort>[];
      final resultsPort = ReceivePort();
      final isolates = <Isolate>[];
      int isolateReadyCount = 0;
      final completer = Completer<void>();

      // 2. 启动隔离区工作线程
      final isolateReadyPort = ReceivePort();
      isolateReadyPort.listen((msg) {
        if (msg is SendPort) {
          isolatePorts.add(msg);
          isolateReadyCount++;
        }
      });

      final isolateCount = min(8, Platform.numberOfProcessors);
      for (int i = 0; i < isolateCount; i++) {
        final isolate = await Isolate.spawn(_isolateAiCaptionGeneration, {
          'readyPort': isolateReadyPort.sendPort,
          'resultsPort': resultsPort.sendPort,
          'apiUrl': apiBaseUrl,
        });
        isolates.add(isolate);
      }

      // 等待所有隔离区准备就绪
      while (isolateReadyCount < isolateCount) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      isolateReadyPort.close();

      // 3. 分发任务
      final tasksPerIsolate = (selectedImages.length / isolateCount).ceil();
      for (int i = 0; i < isolateCount; i++) {
        final start = i * tasksPerIsolate;
        final end = min((i + 1) * tasksPerIsolate, selectedImages.length);
        if (start < end) {
          final batch = selectedImages.sublist(start, end);
          isolatePorts[i].send({
            'type': 'tasks',
            'images': batch.map((img) => img.toJson()).toList(),
          });
        }
      }

      // 4. 结果处理
      final subscription = resultsPort.listen((result) async {
        if (processCancelled) return;

        processedCount++;
        if (updateDialogState != null) updateDialogState!(() {});

        final imageId = result['imageId'] as int;
        final status = result['status'] as String;
        final caption = result['caption'] as String?;

        if (status == 'success' && caption != null) {
          successCount++;
          // 更新本地UI状态
          setState(() {
            _captionControllers[imageId.toString()]?.text = caption;
          });
        } else {
          errorCount++;
          final errorMsg = result['error'] ?? '未知错误';
          errors.add('${result['imageName']}: $errorMsg');
        }

        // 所有任务完成
        if (processedCount >= selectedImages.length) {
          completer.complete();
        }
      });

      // 5. 等待任务完成
      await completer.future;
      subscription.cancel();
      resultsPort.close();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理出错: ${e.toString()}')));
    } finally {
      if (isDialogOpen) Navigator.pop(context);

      // 显示最终结果
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('批量处理完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总计处理: ${selectedImages.length}张'),
              Text('成功: $successCount'),
              Text('失败: $errorCount'),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '失败图片:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...errors.map(
                  (e) => Text(e, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 隔离区任务处理函数
  static void _isolateAiCaptionGeneration(dynamic initData) async {
    final readyPort = initData['readyPort'] as SendPort;
    final resultsPort = initData['resultsPort'] as SendPort;
    final apiUrl = initData['apiUrl'] as String;

    // 注册当前隔离区
    final isolatePort = ReceivePort();
    readyPort.send(isolatePort.sendPort);

    // 任务处理器
    isolatePort.listen((message) async {
      if (message['type'] == 'tasks') {
        final imagesJson = message['images'] as List;
        final images = imagesJson
            .map((json) => ImageModel.fromJson(json))
            .toList();

        for (final img in images) {
          try {
            // 1. 下载图片
            final imgUrl = '$apiUrl/img/${img.imgPath}';
            final base64Image =
                await ImageService.downloadImageAndConvertToBase64(imgUrl);

            // 2. 调用AI生成描述
            final aiResponse = await ImageService.getImageCaptionFromAI(
              base64Image,
              img,
            );
            final caption = aiResponse.content;

            // 返回结果到主线程
            resultsPort.send({
              'status': 'success',
              'imageId': img.imageID,
              'imageName': img.imgName,
              'caption': caption,
            });
          } catch (e) {
            resultsPort.send({
              'status': 'error',
              'imageId': img.imageID,
              'imageName': img.imgName,
              'error': e.toString(),
            });
          }
        }
      }
    });
  }

  // 改进的URL构建方法，添加错误处理
  String? _buildImageUrl(String? imgPath) {
    if (imgPath == null || imgPath.isEmpty) return null;

    try {
      // 创建基本路径
      String fullPath = imgPath.startsWith('/')
          ? imgPath.substring(1)
          : imgPath;
      fullPath = '$imgBasePath$fullPath';
      // 创建完整URL并编码
      final url = Uri.encodeFull('$apiBaseUrl$fullPath');
      // 如果之前加载失败过，直接返回null
      if (_failedUrls.contains(url)) return null;

      return url;
    } catch (e) {
      print('图片URL构建失败: $e');
      return null;
    }
  }

  // 安全获取图片提供器的方法
  // 安全获取图片提供器的方法（移除缓存）
  ImageProvider _getSafeImageProvider(String? imgPath) {
    if (imgPath == null) {
      return const AssetImage('assets/image_unavailable.png');
    }

    final url = _buildImageUrl(imgPath);
    if (url == null) {
      return const AssetImage('assets/image_unavailable.png');
    }

    // 直接返回NetworkImage
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _taskData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('错误: ${snapshot.error}'));
          }

          final task = snapshot.data!['task'];

          return Column(
            children: [
              // 顶部状态栏 - 添加了多选和全选按钮
              _buildTaskStatusBar(task, _images),
              const SizedBox(height: 16),
              // 主内容区域
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 图片列表 (3/10宽度)
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.2,
                      child: _buildImageList(_images),
                    ),
                    const VerticalDivider(width: 1),
                    // 图片详情区域 (7/10宽度)
                    Expanded(
                      child: _isSelecting && _selectedImageIds.isNotEmpty
                          ? _buildBatchProcessingView()
                          : _selectedImage != null
                          ? _buildImageDetail(_selectedImage!)
                          : const Center(child: Text('请选择图片')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskStatusBar(
    Map<String, dynamic> task,
    List<ImageModel> images,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：选择按钮 + 返回按钮 + 任务ID
          Row(
            children: [
              // 多选按钮
              IconButton(
                icon: Icon(_isSelecting ? Icons.deselect : Icons.select_all),
                onPressed: _toggleSelectMode,
                tooltip: _isSelecting ? '退出多选' : '多选',
              ),

              // 全选按钮（只在多选模式下显示）
              if (_isSelecting) ...[
                IconButton(
                  icon: Icon(
                    _selectedImageIds.length == images.length
                        ? Icons.check_box_outline_blank
                        : Icons.check_box,
                  ),
                  onPressed: _toggleSelectAll,
                  tooltip: _selectedImageIds.length == images.length
                      ? '取消全选'
                      : '全选',
                ),
                SizedBox(width: 8),
                Text('已选: ${_selectedImageIds.length}'),
              ] else ...[
                // 返回按钮（正常模式下显示）
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '返回',
                ),
              ],

              const SizedBox(width: 12),
              Text(
                '任务ID: ${task['checkImageListID']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // 中间：图片统计信息
          Row(
            children: [
              Text(
                '图片总数: ${task['imageCount']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 24),
              Text(
                '已检查数: ${task['checked_count']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // 右侧：状态信息
          Text(
            '状态: ${_getStatusText(task['state'])}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getStatusColor(task['state']),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(int state) {
    return switch (state) {
      0 => '待处理',
      1 => '进行中',
      2 => '已完成',
      _ => '未知状态',
    };
  }

  Color _getStatusColor(int state) {
    return switch (state) {
      0 => Colors.orange,
      1 => Colors.blue,
      2 => Colors.green,
      _ => Colors.grey,
    };
  }

  // 图片列表项添加复选框（多选模式下）
  Widget _buildImageList(List<ImageModel> images) {
    return ListView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final imageId = image.imageID;
        _selectedImageIds.contains(imageId);
        final isDiscarded = image.state == 5; // 废弃状态
        return Container(
          // 为废弃的图片添加红色边框
          decoration: BoxDecoration(
            border: Border.all(
              color: isDiscarded ? Colors.red : Colors.transparent,
              width: 3,
            ),
          ),
          child: Stack(
            children: [
              InkWell(
                onTap: () => _handleImageTap(image.imageID),
                hoverColor: Colors.grey[200],
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _selectedImage?.imageID == image.imageID &&
                            !_isSelecting
                        ? Colors.blue[50]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          _selectedImage?.imageID == image.imageID &&
                              !_isSelecting
                          ? Colors.blue
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 多选模式下显示复选框
                      if (_isSelecting) ...[
                        Checkbox(
                          value: _selectedImageIds.contains(image.imageID),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedImageIds.add(image.imageID);
                              } else {
                                _selectedImageIds.remove(image.imageID);
                              }
                            });
                          },
                        ),
                        SizedBox(width: 8),
                      ],

                      // 缩略图
                      Container(
                        width: 60,
                        height: 60,
                        child: _buildSafeImage(
                          _getSafeImageProvider(image.imgPath),
                          BoxFit.cover,
                          imgPath: image.imgPath,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 图片信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              image.imgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'MD5: ${image.md5}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '分类: ${image.chinaElementName}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_buildImageUrl(image.imgPath) == null)
                              const Text(
                                '图片不可用',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 替换原代码中的废弃图片覆盖层
              if (isDiscarded)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.block,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 批量处理视图
  Widget _buildBatchProcessingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 批量处理状态信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('批量处理任务', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 16),
                  Text('已选择 ${_selectedImageIds.length} 张图片'),
                  SizedBox(height: 8),

                  if (_isBatchProcessing) ...[
                    SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _batchProgress / 100,
                      backgroundColor: Colors.grey[300],
                      minHeight: 8,
                    ),
                    SizedBox(height: 8),
                    Text('处理中: $_batchProgress%'),
                    Text('成功: $_batchSuccessCount, 失败: $_batchErrorCount'),
                    if (_batchErrors.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text('错误信息:', style: TextStyle(color: Colors.red)),
                      ..._batchErrors
                          .take(3)
                          .map(
                            (error) => Text(
                              error,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                    ],
                  ] else if (_batchSuccessCount + _batchErrorCount > 0) ...[
                    SizedBox(height: 16),
                    Text('处理完成!', style: TextStyle(color: Colors.green)),
                    Text('成功: $_batchSuccessCount, 失败: $_batchErrorCount'),
                  ],
                ],
              ),
            ),
          ),

          Spacer(),

          // 批量操作按钮（保留废弃、通过、AI更新）
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isBatchProcessing ? null : _batchAbandonImages,
                  child: Text('废弃'),
                ),
                // ...其他按钮保持不变...
                SizedBox(width: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isBatchProcessing ? null : _batchPassImages,
                  child: Text('通过'),
                ),
                SizedBox(width: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isBatchProcessing
                      ? null
                      : _batchAiGenerateCaptions,
                  child: Text('AI更新'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 在_state类中添加批量操作方法
  // 批量废弃图片
  void _batchAbandonImages() async {
    if (_selectedImageIds.isEmpty) return;

    final imageIds = _selectedImageIds.toList();

    setState(() {
      _isBatchProcessing = true;
      _batchProgress = 0;
      _batchSuccessCount = 0;
      _batchErrorCount = 0;
      _batchErrors.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "states": imageIds.map((id) => {"imageID": id, "state": 5}).toList(),
        }),
      );

      if (response.statusCode == 200) {
        // 更新本地图片状态
        setState(() {
          _images = _images.map((img) {
            if (imageIds.contains(img.imageID)) {
              return img.copyWith(state: 5); // 5 = 废弃状态
            }
            return img;
          }).toList();
        });

        // 更新批处理状态
        setState(() {
          _batchSuccessCount = imageIds.length;
          _batchProgress = 100;
        });

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功废弃 ${_batchSuccessCount} 张图片')),
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _batchErrorCount = imageIds.length;
          _batchErrors.add('批量废弃失败: ${errorData['message'] ?? '未知错误'}');
          _batchProgress = 100;
        });
      }
    } catch (e) {
      setState(() {
        _batchErrorCount = imageIds.length;
        _batchErrors.add('批量废弃失败: ${e.toString()}');
        _batchProgress = 100;
      });
    } finally {
      // 清空选中项并退出批量模式
      if (mounted) {
        setState(() {
          _isBatchProcessing = false;
        });
        // 保持选择模式但清空选择
        _selectedImageIds.clear();
      }
    }
  }

  // 批量通过图片
  void _batchPassImages() async {
    if (_selectedImageIds.isEmpty) return;

    final imageIds = _selectedImageIds.toList();

    setState(() {
      _isBatchProcessing = true;
      _batchProgress = 0;
      _batchSuccessCount = 0;
      _batchErrorCount = 0;
      _batchErrors.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "states": imageIds.map((id) => {"imageID": id, "state": 4}).toList(),
        }),
      );

      if (response.statusCode == 200) {
        // 更新本地图片状态
        setState(() {
          _images = _images.map((img) {
            if (imageIds.contains(img.imageID)) {
              return img.copyWith(state: 4); // 4 = 审核通过
            }
            return img;
          }).toList();
        });

        // 更新批处理状态
        setState(() {
          _batchSuccessCount = imageIds.length;
          _batchProgress = 100;
        });

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功通过 ${_batchSuccessCount} 张图片')),
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _batchErrorCount = imageIds.length;
          _batchErrors.add('批量通过失败: ${errorData['message'] ?? '未知错误'}');
          _batchProgress = 100;
        });
      }
    } catch (e) {
      setState(() {
        _batchErrorCount = imageIds.length;
        _batchErrors.add('批量通过失败: ${e.toString()}');
        _batchProgress = 100;
      });
    } finally {
      // 清空选中项并退出批量模式
      if (mounted) {
        setState(() {
          _isBatchProcessing = false;
        });
        // 保持选择模式但清空选择
        _selectedImageIds.clear();
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _downloadImage() {
    DownloadHelper.downloadImage(
      context: context,
      imgPath: _selectedImage!.imgPath,
      imgName: _selectedImage!.imgName,
    );
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    try {
      final response = await UploadHelper.pickAndUpload(
        context: context,
        imageID: _selectedImage!.imageID,
      );

      if (response != null && mounted) {
        final newImagePath = response['imgPath']?.toString() ?? '';
        final newFileName =
            response['fileName']?.toString() ?? _selectedImage!.imgName;
        final newMd5 = response['md5']?.toString() ?? _selectedImage!.md5;

        // 调试日志
        print('[DEBUG] 更新图片数据:');
        print('旧路径: ${_selectedImage!.imgPath}');
        print('新路径: $newImagePath');
        print('新文件名: $newFileName');
        print('新MD5: $newMd5');

        if (newImagePath.isNotEmpty) {
          setState(() {
            _taskData = _fetchTaskData();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('上传失败: ${e.toString()}')));
      }
    }
  }

  Widget _buildImageDetail(ImageModel image) {
    final controller = _captionControllers[image.imageID.toString()]!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左边：大图区域
          Expanded(
            flex: 6, // 7份宽度
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.1,
                  maxScale: 4.0,
                  child: _buildSafeImage(
                    _getSafeImageProvider(image.imgPath),
                    BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 右边：按钮和信息区域
          Expanded(
            flex: 4, // 4份宽度
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 按钮区域（只保留更新图片和提交按钮）
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('下载'),
                        onPressed: () => _downloadImage(),
                      ),
                      const SizedBox(width: 14), // 适当间距
                      ElevatedButton.icon(
                        icon: const Icon(Icons.image, size: 16),
                        label: const Text('上传图片'),
                        onPressed: () => _uploadImage(),
                      ),
                      const SizedBox(width: 14), // 适当间距
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          '废弃',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => {
                          _setImageState(_selectedImage!.imageID, 5),
                        },
                      ),
                      const SizedBox(width: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          '通过',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => {
                          _setImageState(_selectedImage!.imageID, 4),
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 信息区域
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('图片ID', image.imageID.toString()),
                          _buildDetailRow('文件路径', image.imgPath),
                          _buildDetailRow('文件名称', image.imgName),
                          _buildDetailRow('MD5值', image.md5),
                          _buildDetailRow('分类路径', image.chinaElementName),
                          _buildDetailRow('一级分类', image.First ?? ''),
                          _buildDetailRow('二级分类', image.Second ?? ''),
                          _buildDetailRow('三级分类', image.Third ?? ''),
                          _buildDetailRow('四级分类', image.Fourth ?? ''),
                          _buildDetailRow('五级分类', image.Fifth ?? ''),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              const Text(
                                'Caption:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 40),
                              ElevatedButton(
                                onPressed: () => {
                                  _updateCaptionByhand(
                                    controller.text,
                                    _selectedImage!.imageID,
                                  ),
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text('手动更新'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () => {_batchAiGenerateCaptions()},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    76,
                                    91,
                                    175,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text('AI更新'),
                              ),
                            ],
                          ),
                          // Caption 编辑区域+更新按钮
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              TextField(
                                controller: controller,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 安全图片构建方法
  Widget _buildSafeImage(
    ImageProvider? provider,
    BoxFit fit, {
    String? imgPath,
  }) {
    final url = _buildImageUrl(imgPath);

    return Image(
      image: provider ?? const AssetImage('assets/image_unavailable.png'),
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // 记录加载失败的URL
        if (url != null) {
          _failedUrls.add(url);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        return _buildPlaceholder();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null) {
          return _buildPlaceholder(isLoading: true);
        }
        return child;
      },
    );
  }

  // 图片占位符组件
  Widget _buildPlaceholder({bool isLoading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
