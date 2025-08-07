import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_state.dart';
import 'package:image_process/tools/ImageBatchService.dart';
import 'package:image_process/widget/image_detail.dart';
import 'package:path/path.dart' as path;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/tree_node.dart';
import 'package:image_process/user_session.dart';
import 'package:file_picker/file_picker.dart'; // 添加文件选择器

class GetImageRepetPage extends StatefulWidget {
  const GetImageRepetPage({super.key});

  @override
  State<StatefulWidget> createState() => _GeImageRepetPageState();
}

class _GeImageRepetPageState extends State<GetImageRepetPage> {
  final String _baseUrl = UserSession().baseUrl;
  final String _token = UserSession().token ?? '';
  List<TreeNode> _titleTree = [];
  String? _selectedLevel1;
  String? _selectedLevel2;
  String? _selectedLevel3;
  String? _selectedLevel4;
  String? _selectedLevel5;

  List<String> _level1Options = [];
  List<TreeNode> _level2Nodes = [];
  List<TreeNode> _level3Nodes = [];
  List<TreeNode> _level4Nodes = [];
  List<TreeNode> _level5Nodes = [];

  List<ImageModel> _allImages = [];
  String? _selectedFolderPath;
  bool _loading = false;
  bool _processing = false;
  String? _error;

  // 分页控制
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalImages = 0;
  final int _pageSize = 100;

  // 重复图片分组
  Map<int, List<ImageModel>> _groupedImages = {};
  bool _showDuplicates = false;

  bool _fetchingImages = false; // 添加这个新变量来跟踪图片加载状态

  @override
  void initState() {
    super.initState();
    _loadTitleTree();
  }

  // 加载标题树
  Future<void> _loadTitleTree() async {
    setState(() => _loading = true);

    try {
      final uri = Uri.parse('$_baseUrl/api/image/title-tree');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _titleTree = List<TreeNode>.from(
              data['titleTree'].map((x) => TreeNode.fromJson(x)),
            );
            _level1Options = _titleTree.map((node) => node.title).toList();
            // 重置选择状态
            _level2Nodes = [];
            _level3Nodes = [];
            _level4Nodes = [];
            _level5Nodes = [];
          });
        } else {
          _showMessage('标题获取失败');
        }
      } else if (response.statusCode == 401) {
        _showMessage('请刷新登录信息');
      } else {
        _showMessage('服务器内部错误');
      }
    } catch (e) {
      _showMessage('标题获取失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // 更新多级标题
  void _updateDropdownOptions() {
    // 第一级选择
    if (_selectedLevel1 != null) {
      final level1Node = _titleTree.firstWhere(
        (node) => node.title == _selectedLevel1,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level2Nodes = level1Node.children;
    }

    // 第二级选择
    if (_selectedLevel2 != null && _level2Nodes.isNotEmpty) {
      final level2Node = _level2Nodes.firstWhere(
        (node) => node.title == _selectedLevel2,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level3Nodes = level2Node.children;
    }

    // 第三级选择
    if (_selectedLevel3 != null && _level3Nodes.isNotEmpty) {
      final level3Node = _level3Nodes.firstWhere(
        (node) => node.title == _selectedLevel3,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level4Nodes = level3Node.children;
    }

    // 第四级选择
    if (_selectedLevel4 != null && _level4Nodes.isNotEmpty) {
      final level4Node = _level4Nodes.firstWhere(
        (node) => node.title == _selectedLevel4,
        orElse: () => TreeNode(id: -1, title: '', children: []),
      );
      _level5Nodes = level4Node.children;
    }

    setState(() {});
  }

  // 循环分页查询所有图片
  Future<void> _fetchAllImages() async {
    if (_selectedLevel1 == null) {
      _showMessage('请至少选择一级标题');
      return;
    }

    setState(() {
      _fetchingImages = true; // 设置加载状态
    });

    // 显示加载弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('正在加载图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在加载图片，请稍候... (0/$_totalImages)'),
          ],
        ),
      ),
    );

    try {
      setState(() {
        _allImages.clear();
        _showDuplicates = false;
        _currentPage = 1;
        _totalPages = 1;
        _groupedImages.clear();
      });

      int currentPage = 1;
      int totalImagesFetched = 0;

      // 循环直到获取所有页面
      while (currentPage <= _totalPages) {
        await _fetchImagesByPage(currentPage);

        // 更新下载进度
        totalImagesFetched = _allImages.length;

        // 更新弹窗内容
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('正在加载图片'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('正在加载图片，请稍候... ($totalImagesFetched/$_totalImages)'),
                ],
              ),
            ),
          );
        }

        currentPage++;
      }
    } catch (e) {
      _showMessage('加载失败: $e');
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _fetchingImages = false; // 清除加载状态
        });
      }
    }
  }

  // 单页查询
  Future<void> _fetchImagesByPage(int page) async {
    try {
      final url = Uri.parse('${UserSession().baseUrl}/api/image/by-titles');

      // 构建请求参数
      final params = {
        'page': page.toString(),
        'limit': _pageSize.toString(),
        if (_selectedLevel1!.isNotEmpty) 'First': _selectedLevel1,
        if (_selectedLevel2 != null && _selectedLevel2!.isNotEmpty)
          'Second': _selectedLevel2,
        if (_selectedLevel3 != null && _selectedLevel3!.isNotEmpty)
          'Third': _selectedLevel3,
        if (_selectedLevel4 != null && _selectedLevel4!.isNotEmpty)
          'Fourth': _selectedLevel4,
        if (_selectedLevel5 != null && _selectedLevel5!.isNotEmpty)
          'Fifth': _selectedLevel5,
        'goodState':'true',
      };

      final response = await http.get(
        url.replace(queryParameters: params),
        headers: {'Authorization': 'Bearer ${UserSession().token}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          final List<dynamic> images = data['images'] ?? [];
          _allImages.addAll(
            images.map((item) => ImageModel.fromJson(item)).toList(),
          );
          _totalImages = data['total'] ?? 0;
          _totalPages = (_totalImages / _pageSize).ceil();
        });
      } else {
        throw Exception('查询图片失败(${response.statusCode})');
      }
    } catch (e) {
      throw Exception('查询图片异常: $e');
    }
  }

  // 选择文件夹
  Future<void> _selectFolder() async {
    try {
      String? folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath != null) {
        setState(() => _selectedFolderPath = folderPath);
        _showMessage('已选择文件夹: $folderPath');
      }
    } catch (e) {
      _showMessage('选择文件夹失败: $e');
    }
  }

  // 执行Python脚本分析重复图片
  Future<void> _runPythonScript() async {
    if (_selectedFolderPath == null) {
      _showMessage('请先选择包含图片的文件夹');
      return;
    }

    setState(() {
      _processing = true;
      _showDuplicates = true;
      _error = null;
      _groupedImages.clear();
    });

    // 显示加载弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('正在处理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在分析重复图片，请稍候...'),
          ],
        ),
      ),
    );

    try {
      final script = path.join('${UserSession().getRepetPath}','processImage.exe');
      final result = await Process.run(script, [_selectedFolderPath!]);

      if (result.exitCode != 0) {
        throw Exception(result.stderr);
      }

      final lines = result.stdout.toString().trim().split('\n');
      final parsedGroups = <List<String>>[];

      for (final line in lines) {
        if (line.isEmpty || !line.contains('Group of similar images:'))
          continue;

        final listStart = line.indexOf('[');
        final listEnd = line.lastIndexOf(']') + 1;
        if (listStart == -1 || listEnd == 0) continue;

        final listStr = line
            .substring(listStart, listEnd)
            .replaceAll("'", '"')
            .replaceAll('\\', '\\\\');

        try {
          final group = List<String>.from(json.decode(listStr));
          if (group.length >= 2) {
            parsedGroups.add(group);
          }
        } catch (e) {
          print('解析失败: $line, 错误: $e');
        }
      }

      // 过滤重复分组
      final filteredGroups = <List<String>>[];
      for (final group in parsedGroups) {
        if (group.length < 2) continue;

        bool isSubset = false;
        for (final existingGroup in filteredGroups) {
          if (group.every((path) => existingGroup.contains(path))) {
            isSubset = true;
            break;
          }
        }

        if (!isSubset) {
          filteredGroups.add(group);
        }
      }

      // 根据文件名查询图片详情
      final allImageNames = filteredGroups
          .expand((group) => group)
          .map((path) {
            return path.split(Platform.pathSeparator).last;
          })
          .toSet()
          .toList();

      if (allImageNames.isEmpty) {
        _showMessage('没有需要查询的图片');
        return;
      }

      final url = Uri.parse('${UserSession().baseUrl}/api/image/by-img-names');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'imgNames': allImageNames}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> images = data['images'] ?? [];

        // 创建文件名到ImageModel的映射
        final imageMap = <String, ImageModel>{};
        for (final item in images) {
          final image = ImageModel.fromJson(item);
          imageMap[image.imgName??''] = image;
        }

        // 分组图片
        final groupedMap = <int, List<ImageModel>>{};
        for (int i = 0; i < filteredGroups.length; i++) {
          final group = filteredGroups[i];
          final imageModels = <ImageModel>[];

          for (final path in group) {
            final imgName = path.split(Platform.pathSeparator).last;
            if (imageMap.containsKey(imgName)) {
              imageModels.add(imageMap[imgName]!);
            }
          }

          if (imageModels.isNotEmpty) {
            groupedMap[i] = imageModels;
          }
        }

        setState(() {
          _groupedImages = groupedMap;
        });
      } else {
        throw Exception('查询图片详情失败(${response.statusCode})');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _processing = false);
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 标题选择和功能按钮
          // 修改加载指示器部分
          if (_loading || _fetchingImages) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTitleSelector()),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectFolder,
                  icon: const Icon(Icons.folder, size: 24),
                  tooltip: '选择文件夹',
                ),
                IconButton(
                  onPressed: ()=>{ImageBatchService.downloadImages(context: context,selectedImages: _allImages,path: _selectedFolderPath.toString())},
                  icon: const Icon(Icons.download, size: 24),
                  tooltip: '下载所有图片',
                  color: _selectedFolderPath != null
                      ? Colors.blue
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _fetchAllImages,
                  icon: const Icon(Icons.image, size: 20),
                  label: const Text('查询'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _runPythonScript,
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('查询重复'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF9A9A),
                  ),
                ),
              ],
            ),
          ),

          // 当前选择的文件夹
          if (_selectedFolderPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.folder_open, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '文件夹: $_selectedFolderPath',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // 错误信息
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // 加载指示器
          if (_loading) const LinearProgressIndicator(),

          // 图片显示区域
          Expanded(child: _buildImageGrid()),
        ],
      ),
    );
  }

  /// 构建标题选择器
  Widget _buildTitleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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
      ],
    );
  }

  /// 构建层级下拉框
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
      width: 150,
      child: DropdownButtonFormField<String>(
        value: effectiveValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
        ),
        items: [
          if (options.isEmpty)
            DropdownMenuItem(
              value: null,
              child: Text(
                enabled ? '选择 $hint' : '无可用选项',
                style: TextStyle(
                  color: enabled ? Colors.grey : Colors.grey[400],
                ),
              ),
            )
          else
            ...options.map(
              (title) => DropdownMenuItem(value: title, child: Text(title)),
            ),
        ],
        onChanged: enabled ? onChanged : null,
        disabledHint: const Text('请先选择上级标题'),
      ),
    );
  }

  /// 构建图片网格
  Widget _buildImageGrid() {
    // 处理图片为空的情况
    if (_showDuplicates) {
      if (_groupedImages.isEmpty) {
        return const Center(child: Text('没有重复图片'));
      }

      // 分组显示重复图片
      return ListView.builder(
        itemCount: _groupedImages.length,
        itemBuilder: (context, index) {
          final group = _groupedImages[index]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '重复图片组 ${index + 1} (${group.length}张)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: group.length,
                itemBuilder: (context, idx) {
                  return _buildImageItem(group[idx]);
                },
              ),
              const Divider(height: 20),
            ],
          );
        },
      );
    } else {
      if (_loading) {
        // 显示加载动画
        return const Center(child: CircularProgressIndicator());
      } else if (_allImages.isEmpty) {
        return const Center(child: Text('请选择标题并点击查询按钮'));
      } else {
        // 显示普通图片网格
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: _allImages.length,
          itemBuilder: (context, index) {
            return _buildImageItem(_allImages[index]);
          },
        );
      }
    }
  }

  /// 构建单张图片项
  Widget _buildImageItem(ImageModel image) {
    // 判断图片是否废弃
    final isAbandoned = image.state == ImageState.Abandoned;

    return InkWell(
      onTap: () => _showImageDetail(image),
      child: Container(
        decoration: BoxDecoration(
          // 根据状态设置边框颜色：废弃状态用红色，其他用灰色
          border: Border.all(
            color: isAbandoned ? Colors.red : Colors.grey[300]!,
            // 废弃状态下边框更宽更显眼
            width: isAbandoned ? 2.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 图片缩略图
            Image.network(
              '$_baseUrl/img/${image.imgPath}',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),

            // 如果图片已废弃，显示废弃标识
            if (isAbandoned)
              Container(
                color: Colors.red.withOpacity(0.4), // 半透明红色背景
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 40, color: Colors.white), // 废弃图标
                    SizedBox(height: 8),
                    Text(
                      '废弃',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // 图片信息
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                color: isAbandoned
                    ? Colors.red.withOpacity(0.8) // 废弃状态用红色背景
                    : Colors.black54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image.chinaElementName??'',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        // 废弃状态文字加粗
                        fontWeight: isAbandoned
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      image.imageID.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示图片详情弹窗
  void _showImageDetail(ImageModel image) {
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

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // 状态更新
  Future<void> handleImageUpdated(ImageModel updatedImage) async {
    // 更新父组件的状态
    if (_showDuplicates) {
      // 在分组模式下更新
      if (mounted) {
        setState(() {
          // 遍历所有分组
          _groupedImages.forEach((groupIndex, imagesInGroup) {
            // 在当前分组中查找匹配的图片
            final index = imagesInGroup.indexWhere(
              (img) => img.imageID == updatedImage.imageID,
            );

            // 如果找到匹配的图片，更新它
            if (index != -1) {
              imagesInGroup[index] = updatedImage;

              // 重要：更新Map中的分组引用
              _groupedImages[groupIndex] = imagesInGroup;
            }
          });
        });
      }
    } else {
      // 在普通列表模式下更新
      if (mounted) {
        setState(() {
          final index = _allImages.indexWhere(
            (img) => img.imageID == updatedImage.imageID,
          );
          if (index != -1) {
            _allImages[index] = updatedImage;
          } else {
            _allImages.add(updatedImage); // 如果不存在则添加
          }
        });
      }
    }
  }
}
