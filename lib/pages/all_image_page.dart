import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/model/tree_node.dart';
import 'package:image_process/tools/GetCaption.dart';
import 'package:image_process/tools/ImageBatchService.dart';
import 'package:image_process/user_session.dart';
import 'package:image_process/widget/image_detail.dart';

class AllImagePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AllImagePageState();
}

class AllImagePageState extends State<AllImagePage> {
  final String baseUrl = UserSession().baseUrl;
  late String authToken = UserSession().token ?? '';

  // 添加记录当前选中图片的状态变量
  ImageModel? _selectedImage; // 当前选中的图片

  List<TreeNode> _titleTree = [];

  // 当前选择的标题
  String? _selectedLevel1;
  String? _selectedLevel2;
  String? _selectedLevel3;
  String? _selectedLevel4;
  String? _selectedLevel5;

  // 标题选项
  List<String> _level1Options = [];
  List<TreeNode> _level2Nodes = [];
  List<TreeNode> _level3Nodes = [];
  List<TreeNode> _level4Nodes = [];
  List<TreeNode> _level5Nodes = [];

  List<ImageModel> _images = [];
  int _currentPage = 1;
  int _totalItems = 0;
  int _limit = 60;
  bool _isImagesLoading = false;
  int _gridColumnCount = 4;

  bool _isSelecting = false;
  Set<ImageModel> _selectedImages = {};
  bool _allSelected = false;

  // 用于滚动加载
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTitleTree();
    _scrollController.addListener(_onScroll);
  }

  // 滚动到底部时触发加载
  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isImagesLoading) {
      _loadMoreImages();
    }
  }

  // 加载更多图片
  Future<void> _loadMoreImages() async {
    // 如果正在加载或没有更多数据则退出
    if (_isImagesLoading || !_hasMore) return;
    setState(() => _isImagesLoading = true);
    try {
      final params = {
        'page': (_currentPage + 1).toString(),
        'limit': _limit.toString(),
        if (_selectedLevel1 != null) 'First': _selectedLevel1!,
        if (_selectedLevel2 != null) 'Second': _selectedLevel2!,
        if (_selectedLevel3 != null) 'Third': _selectedLevel3!,
        if (_selectedLevel4 != null) 'Fourth': _selectedLevel4!,
        if (_selectedLevel5 != null) 'Fifth': _selectedLevel5!,
      };

      final uri = Uri.parse(
        '$baseUrl/api/image/by-titles',
      ).replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newImages = List<ImageModel>.from(
          data['images'].map((img) => ImageModel.fromJson(img)),
        );

        setState(() {
          _currentPage++;
          _images.addAll(newImages);
          // 判断是否还有更多数据
          _hasMore = newImages.length >= _limit;
          _totalItems = data['total'];
        });
      }
      // 错误处理保持不变...
    } catch (e) {
      // 错误处理保持不变...
    } finally {
      setState(() => _isImagesLoading = false);
    }
  }

  Future<void> _loadTitleTree() async {
    setState(() {});

    try {
      final uri = Uri.parse('$baseUrl/api/image/title-tree');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _titleTree = List<TreeNode>.from(
              data['titleTree'].map((x) => TreeNode.fromJson(x)),
            );
            _level1Options = _titleTree.map((node) => node.title).toList();
            // 初始化为空节点列表
            _level2Nodes = [];
            _level3Nodes = [];
            _level4Nodes = [];
            _level5Nodes = [];
          });
        } else {
          _showMessage('标题获取失败');
        }
      } else if (response.statusCode == 401) {
        _showMessage('请刷新登陆信息');
      } else {
        _showMessage('服务器内部错误');
      }
    } catch (e) {
      _showMessage('标题获取失败');
    }
  }

  void _updateDropdownOptions() {
    // 如果选择了第一级，更新第二级选项
    if (_selectedLevel1 != null) {
      final level1Node = _titleTree.firstWhere(
        (node) => node.title == _selectedLevel1,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level2Nodes = level1Node.children;
    }

    // 如果选择了第二级，更新第三级选项
    if (_selectedLevel2 != null && _level2Nodes.isNotEmpty) {
      final level2Node = _level2Nodes.firstWhere(
        (node) => node.title == _selectedLevel2,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level3Nodes = level2Node.children;
    }

    // 如果选择了第三级，更新第四级选项
    if (_selectedLevel3 != null && _level3Nodes.isNotEmpty) {
      final level3Node = _level3Nodes.firstWhere(
        (node) => node.title == _selectedLevel3,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level4Nodes = level3Node.children;
    }

    // 如果选择了第四级，更新第五级选项
    if (_selectedLevel4 != null && _level4Nodes.isNotEmpty) {
      final level4Node = _level4Nodes.firstWhere(
        (node) => node.title == _selectedLevel4,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level5Nodes = level4Node.children;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Image'), actions: _buildAppBarActions()),

      body: Column(
        children: [
          // 标题选择器
          _buildTitleSelector(),
          Divider(height: 1),
          // 图片网格视图
          Expanded(
            child: _isImagesLoading && _images.isEmpty
                ? Center(child: CircularProgressIndicator())
                : _images.isEmpty
                ? Center(child: Text('No images found'))
                : _buildImageGridWithLoader(),
          ),
          // 底部选择工具栏
          if (_isSelecting) _buildSelectionToolbar(),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (_isSelecting)
        IconButton(icon: Icon(Icons.cancel), onPressed: _cancelSelection)
      else
        IconButton(
          icon: Icon(Icons.select_all),
          onPressed: _startSelectionMode,
        ),
    ];
  }

  void _startSelectionMode() {
    setState(() {
      _isSelecting = true;
      _selectedImages.clear();
      _allSelected = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectedImages.clear();
      _allSelected = false;
    });
  }

  //底部多选操作兰
  Widget _buildSelectionToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('已选 ${_selectedImages.length} 项'),
          Row(
            children: [
              TextButton(
                onPressed: _toggleSelectAll,
                child: Text(_allSelected ? '取消全选' : '全选'),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.download, color: Colors.green),
                onPressed: () => {
                  ImageBatchService.downloadImages(
                    context: context,
                    selectedImages: _selectedImages.toList(),
                  ),
                },
              ),
              SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 244, 177, 54),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  '更改状态',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => {_setImagesState()},
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 54, 130, 244),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Caption',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => {_batchUpdateCaptions()},
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setImagesState() async {
    if (_selectedImages.isEmpty) {
      _showMessage('请先选择要修改的图片');
      return;
    }

    // 1. 显示状态选择对话框并等待用户选择
    final int? selectedState = await _showStateSelectorDialog(context);

    // 如果用户取消了选择，直接返回
    if (selectedState == null) {
      return;
    }

    // 2. 准备请求数据
    final requestBody = {
      'states': _selectedImages.map((image) {
        return {'imageID': image.imageID, 'state': selectedState};
      }).toList(),
    };

    // 3. 显示加载指示器
    final progressDialogContext = Navigator.of(
      context,
      rootNavigator: true,
    ).context;
    showDialog(
      context: progressDialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('正在更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在更新 ${_selectedImages.length} 张图片状态...'),
          ],
        ),
      ),
    );

    try {
      // 4. 发送请求
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // 5. 处理响应
      if (response.statusCode == 200) {
        // 解析响应数据
        final responseData = jsonDecode(response.body);
        final List<dynamic> results = responseData['results'];

        // 创建ID到更新结果的映射
        final Map<int, Map<String, dynamic>> updateMap = {};
        for (var result in results) {
          updateMap[result['imageID'] as int] = {
            'affectedRows': result['affectedRows'],
            'newState': result['newState'],
          };
        }

        // 更新本地数据 - 只更新状态字段
        setState(() {
          for (var image in List.from(_selectedImages)) {
            if (updateMap.containsKey(image.imageID)) {
              // 只更新状态字段
              final newState = updateMap[image.imageID]!['newState'] as int;

              // 在图片列表中查找该图片并更新状态
              final index = _images.indexWhere(
                (img) => img.imageID == image.imageID,
              );
              if (index != -1) {
                _images[index] = _images[index].copyWith(state: newState);
              }

              // 从选中列表中移除已处理的图片
              _selectedImages.remove(image);
            }
          }

          // 如果没有选中的图片了，退出多选模式
          if (_selectedImages.isEmpty) {
            _isSelecting = false;
          }
        });

        // 显示成功消息
        final successCount = updateMap.length;
        _showMessage('成功更新 $successCount 张图片状态');
      }
      // 处理错误响应
      else if (response.statusCode >= 400 && response.statusCode < 500) {
        final errorResponse = jsonDecode(response.body);
        throw Exception(
          errorResponse['message'] ?? '状态更新失败: ${response.statusCode}',
        );
      } else {
        throw Exception('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      // 显示错误消息
      _showMessage('状态更新失败: ${e.toString()}');
    } finally {
      // 关闭加载对话框
      Navigator.of(progressDialogContext, rootNavigator: true).pop();
    }
  }

  // 状态选择对话框
  Future<int?> _showStateSelectorDialog(BuildContext context) async {
    return await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置图片状态'),
        content: Container(
          width: double.minPositive,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildStateOption(ImageState.ToBeChecked, '未检查', context),
              _buildStateOption(ImageState.Checking, '正在检查', context),
              _buildStateOption(ImageState.UnderReview, '正在审核', context),
              _buildStateOption(ImageState.Approved, '审核通过', context),
              _buildStateOption(ImageState.Abandoned, '废弃', context),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
        ],
      ),
    );
  }

  // 构建状态选项
  Widget _buildStateOption(
    int stateValue,
    String stateName,
    BuildContext context,
  ) {
    return ListTile(
      title: Text(stateName),
      leading: Icon(Icons.circle, color: ImageState.getStateColor(stateValue)),
      onTap: () => Navigator.pop(context, stateValue),
    );
  }

  Future<void> _batchUpdateCaptions() async {
    if (_selectedImages.isEmpty) {
      _showMessage('请先选择要更新的图片');
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
      resultsSubscription.cancel();
      resultsPort.close();

      // 9. 关闭所有隔离区
      for (var isolate in isolates) {
        isolate.kill();
      }
    } catch (e) {
      _showMessage('批量更新出错: ${e.toString()}');
    } finally {
      if (isDialogOpen) {
        Navigator.of(context).pop();
      }

      // 显示最终结果
      final result = '成功更新: $successCount, 失败: $errorCount';
      _showMessage(result);
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

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedImages.clear();
      } else {
        _selectedImages = Set.from(_images.map((img) => img));
      }
      _allSelected = !_allSelected;
    });
  }

  // 网格视图
  Widget _buildImageGridWithLoader() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 确保仅在列表需要时响应滚动
        return true;
      },
      child: Stack(
        children: [
          // 图片网格
          GridView.builder(
            controller: _scrollController, // 添加滚动控制器
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridColumnCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: _images.length + (_hasMore ? 1 : 0), // 为加载指示器预留位置
            itemBuilder: (context, index) {
              if (index < _images.length) {
                return _buildImageCard(_images[index]);
              } else {
                // 显示底部加载指示器
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),

          // 顶部加载指示器（用于初始加载）
          if (_isImagesLoading && _images.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // 一级标题下拉框
          _buildLevelDropdown(
            value: _selectedLevel1,
            options: _level1Options,
            hint: '一级标题',
            onChanged: (value) {
              setState(() => _selectedLevel1 = value);
              _updateDropdownOptions();
              _selectedLevel2 = null;
              _selectedLevel3 = null;
              _selectedLevel4 = null;
              _selectedLevel5 = null;
            },
          ),
          // 二级标题下拉框
          _buildLevelDropdown(
            value: _selectedLevel2,
            options: _level2Nodes.map((node) => node.title).toList(),
            hint: '二级标题',
            enabled: _level2Nodes.isNotEmpty,
            onChanged: _level2Nodes.isNotEmpty
                ? (value) {
                    setState(() => _selectedLevel2 = value);
                    _updateDropdownOptions();
                    _selectedLevel3 = null;
                    _selectedLevel4 = null;
                    _selectedLevel5 = null;
                  }
                : null,
          ),

          // 三级标题下拉框
          _buildLevelDropdown(
            value: _selectedLevel3,
            options: _level3Nodes.map((node) => node.title).toList(),
            hint: '三级标题',
            enabled: _level3Nodes.isNotEmpty,
            onChanged: _level3Nodes.isNotEmpty
                ? (value) {
                    setState(() => _selectedLevel3 = value);
                    _updateDropdownOptions();
                    _selectedLevel4 = null;
                    _selectedLevel5 = null;
                  }
                : null,
          ),
          // 四级标题下拉框
          _buildLevelDropdown(
            value: _selectedLevel4,
            options: _level4Nodes.map((node) => node.title).toList(),
            hint: '四级标题',
            enabled: _level4Nodes.isNotEmpty,
            onChanged: _level4Nodes.isNotEmpty
                ? (value) {
                    setState(() => _selectedLevel4 = value);
                    _updateDropdownOptions();
                    _selectedLevel5 = null;
                  }
                : null,
          ),
          // 五级标题下拉框
          _buildLevelDropdown(
            value: _selectedLevel5,
            options: _level5Nodes.map((node) => node.title).toList(),
            hint: '五级标题',
            enabled: _level5Nodes.isNotEmpty,
            onChanged: _level5Nodes.isNotEmpty
                ? (value) {
                    setState(() => _selectedLevel5 = value);
                  }
                : null,
          ),
          // 搜索按钮
          ElevatedButton(
            onPressed: () => {
              _images.clear(),
              _totalItems = 0,
              _currentPage = 0,
              _hasMore = true,
              _isImagesLoading = false,
              _loadMoreImages(),
            },
            child: Text('查询'),
          ),
          SizedBox(width: 20),
          // 列数控制
          _buildColumnController(),
        ],
      ),
    );
  }

  Widget _buildLevelDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
  }) {
    // 确保当前值存在于选项中
    final effectiveValue = options.contains(value) ? value : null;
    return Container(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: effectiveValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(),
        ),
        items: [
          if (options.isEmpty)
            DropdownMenuItem(
              value: null,
              child: Text(
                enabled ? '选择 $hint' : '无可用选项',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...options.map(
              (title) => DropdownMenuItem(value: title, child: Text(title)),
            ),
        ],
        onChanged: onChanged,
        disabledHint: Text('请先选择上级标题'),
      ),
    );
  }

  // 列数调整控制器
  Widget _buildColumnController() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('列数:'),
        SizedBox(width: 10),
        // 减列按钮
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            if (_gridColumnCount > 4) {
              setState(() => _gridColumnCount--);
            }
          },
        ),
        // 当前列数
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$_gridColumnCount'),
        ),
        // 加列按钮
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            if (_gridColumnCount < 8) {
              setState(() => _gridColumnCount++);
            }
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(ImageModel image) {
    final imageUrl = '$baseUrl/img/${image.imgPath}';
    final isSelected = _isSelecting && _selectedImages.contains(image);
    final isDiscarded = image.state == ImageState.Abandoned;
    final isCurrentSelected = !_isSelecting && _selectedImage == image; // 当前选中状态

    return Stack(
      children: [
        Card(
          // elevation: isSelected ? 4 : 2,
          elevation: isCurrentSelected ? 8 : 2, // 增加选中卡片的高度
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCurrentSelected 
                ? Colors.blueAccent // 高亮蓝色边框
                : isDiscarded
                  ? Colors.red
                  : isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
              width: isCurrentSelected ? 3 : 2, // 加粗边框
            ),
          ),
          child: InkWell(
            onTap: () {
              if (_isSelecting) {
                setState(() {
                  if (_selectedImages.contains(image)) {
                    _selectedImages.remove(image);
                  } else {
                    _selectedImages.add(image);
                  }
                  // 如果选中的数量等于所有图片数量，则全选
                  if (_selectedImages.length == _images.length) {
                    _allSelected = true;
                  } else {
                    _allSelected = false;
                  }
                });
              } else {
                _showImageDetail(image);
              }
            },
            onLongPress: () {
              if (!_isSelecting) {
                _startSelectionMode();
                setState(() {
                  _selectedImages.add(image);
                });
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 图片显示
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    child: _buildImageWithFallback(imageUrl),
                  ),
                ),

                // 图片信息
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.chinaElementName??'',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        image.imageID.toString(),
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 添加选中标记（蓝色圆角标记）
        // if (isCurrentSelected) Positioned(
        //   top: 5,
        //   right: 5,
        //   child: Container(
        //     padding: EdgeInsets.all(4),
        //     decoration: BoxDecoration(
        //       color: Colors.blueAccent,
        //       shape: BoxShape.circle,
        //     ),
        //     child: Icon(
        //       Icons.check,
        //       size: 16,
        //       color: Colors.white,
        //     ),
        //   ),
        // ),
        // 废弃标签
        if (isDiscarded)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '废弃',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // 选择勾选标记
        if (_isSelecting)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }

  Future<void> handleImageUpdated(ImageModel uploadImage) async {
    // 更新父组件的状态
    if (mounted) {
      setState(() {
        final index = _images.indexWhere(
          (img) => img.imageID == uploadImage.imageID,
        );
        if (index != -1) {
          _images[index] = uploadImage;
        } else {
          _images.add(uploadImage); // 如果不存在则添加
        }
      });
    }
  }

  void _showImageDetail(ImageModel image) {
    setState(() {
      _selectedImage = image; // 标记选中的图片
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        ImageModel currentImage = image;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        // 使用Flexible
                        child: ImageDetail(
                          key: ValueKey(currentImage.imageID), // 确保更新后的重建
                          image: currentImage,
                          onUpload: handleImageUpdated,
                          onClose: () => Navigator.pop(context),
                          onAIGenerate: handleImageUpdated,
                          onUpdateState: handleImageUpdated,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageWithFallback(String url) {
    // 使用Image.network并添加错误处理
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => Container(
        color: Colors.grey[200],
        child: Center(child: Icon(Icons.broken_image)),
      ),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
