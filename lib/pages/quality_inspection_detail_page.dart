import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/tools/GetCaption.dart';
import 'package:image_process/tools/ImageBatchService.dart';
import 'package:image_process/user_session.dart';
import 'package:image_process/widget/image_detail.dart';

class QualityInspectionDetailPage extends StatefulWidget {
  final int taskId;

  const QualityInspectionDetailPage({super.key, required this.taskId});

  @override
  State<QualityInspectionDetailPage> createState() =>
      _QualityInspectionDetailPageState();
}

class _QualityInspectionDetailPageState
    extends State<QualityInspectionDetailPage> {
  List<ImageModel> _images = [];
  ImageModel? _selectedImage;
  List<ImageModel> _selectedImages = [];
  bool _isSelecting = false;
  final String _baseUrl = UserSession().baseUrl;
  final String _token = UserSession().token ?? '';

  @override
  void initState() {
    super.initState();
    _fetchTaskData();
  }

  Future<void> _fetchTaskData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/check-tasks/${widget.taskId}'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final imagesJson = jsonData['images'] as List;

        setState(() {
          _images = imagesJson.map((img) => ImageModel.fromJson(img)).toList();
          // 默认选中第一张图片
          if (_images.isNotEmpty) {
            _selectedImage = _images.first;
          }
        });
      } else {
        throw Exception('获取任务详情失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取任务详情异常: $e');
    }
  }

  void _toggleSelection(ImageModel image) {
    setState(() {
      if (_isSelecting) {
        if (_selectedImages.contains(image)) {
          _selectedImages.remove(image);
        } else {
          _selectedImages.add(image);
        }
      } else {
        _selectedImage = image;
      }
    });
  }

  void _toggleAllSelection(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedImages = List.from(_images);
      } else {
        _selectedImages.clear();
      }
    });
  }

  void _toggleSelectingMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _selectedImages.clear();
    });
  }

  void _updateImage(ImageModel updatedImage) {
    setState(() {
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
        if (_selectedImage?.imageID == updatedImage.imageID) {
          _selectedImage = updatedImage;
        }
      }
    });
  }

  void _batchUpdateState(int state) async {
    try {
      if (_selectedImages.isEmpty) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "states": _selectedImages
              .map((img) => {"imageID": img.imageID, "state": state})
              .toList(),
        }),
      );
      print(response.body);
      if (response.statusCode == 200) {
        setState(() {
          // 更新所有选中图片的状态
          for (var img in _selectedImages) {
            final updatedImg = img.copyWith(state: state);
            _updateImage(updatedImg);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功更新 ${_selectedImages.length} 张图片状态')),
        );
      } else {
        throw Exception('批量更新状态失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('批量更新异常: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  Future<void> _batchUpdateCaptions() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请选择图片')));
      return;
    }

    // 1. 准备进度对话框
    bool isDialogOpen = false;
    void Function(void Function())? updateDialogState;
    bool processCancelled = false;
    int processedCount = 0;
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];
    Completer<void>? completer; // 用于等待任务完成的Completer

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        isDialogOpen = true;
        return StatefulBuilder(
          builder: (context, setState) {
            updateDialogState = setState;
            return AlertDialog(
              title: const Text('批量更新Caption中'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: processedCount / _selectedImages.length,
                  ),
                  const SizedBox(height: 16),
                  Text('已处理: $processedCount/${_selectedImages.length}'),
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
                    completer?.complete(); // 完成completer以退出等待
                    Navigator.of(context).pop();
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
      // 2. 使用不同的ReceivePort来处理不同的消息类型
      final isolatePorts = <SendPort>[];
      final resultsPort = ReceivePort(); // 用于接收结果
      final isolates = <Isolate>[];
      int isolateReadyCount = 0;

      // 使用单独的端口来接收isolate准备好的消息
      final isolateReadyPort = ReceivePort();
      isolateReadyPort.listen((message) {
        if (message is SendPort) {
          isolatePorts.add(message);
          isolateReadyCount++;
        }
      });
      // 3. 启动隔离区
      final isolateCount = min(8, Platform.numberOfProcessors);
      for (int i = 0; i < isolateCount; i++) {
        final isolate = await Isolate.spawn(_isolateCaptionUpdate, {
          'mainSendPort': isolateReadyPort.sendPort, // 用于发送isolate的SendPort
          'resultSendPort': resultsPort.sendPort, // 用于发送任务结果
          'token': UserSession().token,
          'baseUrl': UserSession().baseUrl,
        });
        isolates.add(isolate);
      }

      // 等待所有隔离区准备好
      await Future.doWhile(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return isolateReadyCount < isolateCount;
      });

      // 关闭isolate准备端口
      isolateReadyPort.close();
      // 4. 分发任务给各隔离区
      final tasksPerIsolate = (_selectedImages.length / isolateCount).ceil();
      for (int i = 0; i < isolateCount; i++) {
        final startIndex = i * tasksPerIsolate;
        final endIndex = min((i + 1) * tasksPerIsolate, _selectedImages.length);
        if (startIndex < endIndex) {
          final imagesForIsolate = _selectedImages.toList().sublist(
            startIndex,
            endIndex,
          );
          isolatePorts[i].send({
            'type': 'tasks',
            'images': imagesForIsolate.map((img) => img.toJson()).toList(),
          });
        }
      }
      // 5. 声明Completer用于等待任务完成
      completer = Completer<void>();
      // 6. 处理结果
      StreamSubscription? resultsSubscription;
      resultsSubscription = resultsPort.listen((response) async {
        if (processCancelled) return;

        final status = response['status'];
        final imageName = response['imageName'] ?? '';
        final message = response['message'] ?? '';

        setState(() {
          processedCount++;
          if (status == 'success') {
            successCount++;
            // 更新本地数据
            _images = _images.map((img) {
              if (img.imgName == imageName) {
                return img.copyWith(caption: message);
              }
              return img;
            }).toList();
          } else {
            errorCount++;
            if (errors.length < 5) {
              errors.add('$imageName: $message');
            }
          }
        });
        if (updateDialogState != null) {
          updateDialogState!(() {});
        }
        // 所有任务完成
        if (processedCount >= _selectedImages.length) {
          completer?.complete();
        }
      });
      // 7. 等待任务完成
      await completer.future;
      // 8. 清理资源
      resultsSubscription?.cancel();
      resultsPort.close();
      // 9. 关闭所有隔离区
      for (var isolate in isolates) {
        isolate.kill();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批量更新出错${e.toString()}')));
    } finally {
      if (isDialogOpen) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功更新 $successCount, 失败: $errorCount')),
      );
    }
  }

  static void _isolateCaptionUpdate(Map<String, dynamic> initData) async {
    final baseUrl = initData['baseUrl'] as String;
    final mainSendPort = initData['mainSendPort'] as SendPort;
    final resultSendPort = initData['resultSendPort'] as SendPort;
    final token = initData['token'] as String;
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
              token: token,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('共 ${_images.length} 张图片'),
        actions: [
          if (_isSelecting)
            IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: _toggleSelectingMode,
              tooltip: '退出多选模式',
            ),
          if (!_isSelecting && _images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectingMode,
              tooltip: '进入多选模式',
            ),
        ],
      ),
      body: _images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // 左侧图片列表 (占1/3)
                Container(
                  width: MediaQuery.of(context).size.width / 4,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      // 列表顶部操作栏
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isSelecting)
                              Checkbox(
                                value: _selectedImages.length == _images.length,
                                tristate: false,
                                onChanged: (value) =>
                                    _toggleAllSelection(value ?? false),
                              ),
                            if (_isSelecting)
                              Text('已选 ${_selectedImages.length} 张'),
                            const Spacer(),
                            if (_isSelecting)
                              IconButton(
                                icon: const Icon(Icons.check_circle),
                                color: Colors.green,
                                onPressed: () => _batchUpdateState(ImageState.Approved),
                                tooltip: '批量通过',
                              ),
                            if (_isSelecting)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red,
                                onPressed: () => _batchUpdateState(ImageState.Abandoned),
                                tooltip: '批量废弃',
                              ),
                          ],
                        ),
                      ),
                      // 图片列表
                      Expanded(
                        child: ListView.builder(
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            final image = _images[index];
                            final isSelected = _isSelecting
                                ? _selectedImages.contains(image)
                                : _selectedImage == image;

                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue[50] : null,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: ListTile(
                                leading: _isSelecting
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (value) =>
                                            _toggleSelection(image),
                                      )
                                    : Image.network(
                                        '$_baseUrl/img/${image.imgPath}',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.broken_image,
                                              );
                                            },
                                      ),
                                title: Text(
                                  image.chinaElementName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'ID: ${image.imageID} • ${ImageState.getStateText(image.state ?? 0)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ImageState.getStateColor(
                                      image.state ?? 0,
                                    ),
                                  ),
                                ),
                                onTap: () => _toggleSelection(image),
                                onLongPress: () {
                                  if (!_isSelecting) {
                                    setState(() {
                                      _isSelecting = true;
                                      _selectedImages.add(image);
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧详情区域 (占2/3)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isSelecting
                        ? _buildBatchProcessView()
                        : _selectedImage == null
                        ? const Center(child: Text('请选择一张图片'))
                        : ImageDetail(
                            key: ValueKey(_selectedImage!.imageID),
                            image: _selectedImage!,
                            onImageUpdated: _updateImage,
                            onClose: () =>
                                setState(() => _selectedImage = null),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBatchProcessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '批量操作',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: [
            ChoiceChip(
              label: const Text('设置为通过'),
              selected: false,
              onSelected: (_) => _batchUpdateState(ImageState.Approved),
              avatar: const Icon(Icons.check, color: Colors.green),
              selectedColor: Colors.green[100],
            ),
            ChoiceChip(
              label: const Text('设置为废弃'),
              selected: false,
              onSelected: (_) => _batchUpdateState(ImageState.Abandoned),
              avatar: const Icon(Icons.delete, color: Colors.red),
              selectedColor: Colors.red[100],
            ),
            ChoiceChip(
              label: const Text('Caption'),
              selected: false,
              onSelected: (_) => _batchUpdateCaptions(),
              avatar: const Icon(Icons.delete, color: Color.fromARGB(255, 54, 143, 244)),
              selectedColor: Colors.red[100],
            ),
            ChoiceChip(
              label: const Text('下载'),
              selected: false,
              onSelected: (_) => ImageBatchService.downloadImages(context: context, selectedImages: _selectedImages),
              avatar: const Icon(Icons.delete, color: Color.fromARGB(255, 244, 209, 54)),
              selectedColor: Colors.red[100],
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          '已选图片',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        if (_selectedImages.isEmpty)
          const Text('未选择任何图片')
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: ImageState.getStateColor(image.state ?? 0),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      imagePreview(image),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          color: Colors.black54,
                          child: Text(
                            image.chinaElementName.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget imagePreview(ImageModel image) {
    return Image.network(
      '$_baseUrl/img/${image.imgPath}',
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }
}
