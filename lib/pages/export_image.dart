import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/title_type.dart';
import 'package:image_process/model/tree_node.dart';
import 'package:image_process/user_session.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class ExportImage extends StatefulWidget {
  const ExportImage({super.key});

  @override
  _ExportImageState createState() => _ExportImageState();
}

class _ExportImageState extends State<ExportImage> {
  final _baseUrl = UserSession().baseUrl;
  final _token = UserSession().token ?? '';
  TitleTypes? titleTypes;
  Map<String, String?> selectedTitles = {
    'First': null,
    'Second': null,
    'Third': null,
    'Fourth': null,
    'Fifth': null,
  };

  // 导出状态变量
  bool _isExporting = false;
  bool _exportCanceled = false;
  int _totalImages = 0;
  int _exportedImages = 0;
  List<Map<String, dynamic>> _exportLog = [];
  StreamController<String> _statusStream = StreamController.broadcast();
  StreamController<int> _progressStream = StreamController.broadcast();

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

  @override
  void initState() {
    super.initState();
    fetchTitleTypes();
    _loadTitleTree();
  }

  @override
  void dispose() {
    _statusStream.close();
    _progressStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleSelector(),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isExporting ? null : _startExport,
                child: const Text('开始导出', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(child: _buildExportLog()),
          ],
        ),
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
        ],
      ),
    );
  }

  Future<void> _loadTitleTree() async {
    setState(() {});

    try {
      final uri = Uri.parse('${UserSession().baseUrl}/api/image/title-tree');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${UserSession().token}'},
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

  // 构建导出日志视图
  Widget _buildExportLog() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导出日志', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _exportLog.length,
                itemBuilder: (context, index) {
                  final entry = _exportLog[index];
                  return ListTile(
                    leading: Icon(
                      entry['success'] ? Icons.check : Icons.error,
                      color: entry['success'] ? Colors.green : Colors.red,
                    ),
                    title: Text(entry['message']),
                    subtitle: Text(entry['timestamp']),
                  );
                },
              ),
            ),
            if (_isExporting) ...[
              const Divider(),
              StreamBuilder<String>(
                stream: _statusStream.stream,
                builder: (context, snapshot) {
                  return Text(snapshot.data ?? '正在导出...');
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<int>(
                stream: _progressStream.stream,
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0;
                  return LinearProgressIndicator(
                    value: progress > 0 ? progress / 100 : 0,
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _cancelExport,
                  child: const Text('取消导出'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 获取标题类型
  Future<void> fetchTitleTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/image/title-types'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          titleTypes = TitleTypes.fromJson(json.decode(response.body));
        });
      } else {
        _showError('获取标题失败: ${response.statusCode}');
      }
    } catch (e) {
      _showError('网络错误: ${e.toString()}');
    }
  }

  // 开始导出流程
  Future<void> _startExport() async {

    // 重置导出状态
    setState(() {
      _isExporting = true;
      _exportCanceled = false;
      _exportedImages = 0;
      _exportLog = [];
    });
    _statusStream.add('选择导出目录...');
    _addLog('开始导出任务');

    // 用户选择导出目录
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath();
    if (selectedDirectory == null) {
      setState(() => _isExporting = false);
      _addLog('用户取消了目录选择');
      return;
    }

    try {
      final images = await _fetchAllImages();
      if (images.isEmpty) {
        _addLog('没有找到符合条件的图片');
        return;
      }

      _totalImages = images.length;
      _statusStream.add('共找到 $_totalImages 张图片');
      _addLog('开始导出 $_totalImages 张图片');

      await _exportToDirectory(images, selectedDirectory);

      if (!_exportCanceled) {
        _addLog('导出完成! 共导出 $_exportedImages 张图片');
        _statusStream.add('导出完成!');
      }
    } catch (e) {
      _showError('导出失败: ${e.toString()}');
      _addLog('导出出错: ${e.toString()}', success: false);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // 获取所有符合条件的图片
  Future<List<ImageModel>> _fetchAllImages() async {
    _addLog('正在获取图片数据...');
    _statusStream.add('查询图片数据...');

    int page = 1;
    int limit = 100;
    List<ImageModel> allImages = [];
    bool moreData = true;

    while (moreData && !_exportCanceled) {
      _statusStream.add('正在获取第 $page 页数据...');

      final uri = Uri.parse('$_baseUrl/api/image/by-titles').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          'goodState': 'true',
          if (_selectedLevel1 != null) 'First': _selectedLevel1!,
          if (_selectedLevel2 != null) 'Second': _selectedLevel2!,
          if (_selectedLevel3 != null) 'Third': _selectedLevel3!,
          if (_selectedLevel4 != null) 'Fourth': _selectedLevel4!,
          if (_selectedLevel5 != null) 'Fifth': _selectedLevel5!,
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final images = (data['images'] as List)
            .map((img) => ImageModel.fromJson(img))
            .toList();

        allImages.addAll(images);
        _addLog('获取第 $page 页数据: ${images.length} 张图片');

        // 检查是否还有更多数据
        if (images.length < limit || allImages.length >= data['total']) {
          moreData = false;
        } else {
          page++;
        }
      } else if (response.statusCode == 401) {
        _showError('未授权，请重新登录');
        _exportCanceled = true;
      } else {
        throw Exception('API错误: ${response.statusCode}');
      }
    }

    return allImages;
  }

  // 导出到目录
  Future<void> _exportToDirectory(
    List<ImageModel> images,
    String baseDir,
  ) async {
    for (var image in images) {
      if (_exportCanceled) break;

      // 更新进度状态
      _exportedImages++;
      final progress = (_exportedImages / _totalImages * 100).toInt();
      _progressStream.add(progress);

      try {
        // 创建层级目录
        final dirPath = _createImageDirectory(baseDir, image);
        final dir = Directory(dirPath);
        if (!dir.existsSync()) dir.createSync(recursive: true);

        // 下载图片
        _statusStream.add('下载图片: ${image.imgName}');
        await _downloadImage(image, dirPath);

        // 创建/更新JSON信息文件
        await _updateImageInfoFile(image, dirPath);

        _addLog('成功导出: ${image.imgName}');
      } catch (e) {
        _addLog('导出失败: ${image.imgName} (${e.toString()})', success: false);
      }
    }
  }

  String _getJsonName(ImageModel image) {
    if (image.Fifth != null) {
      return image.Fifth.toString();
    } else if (image.Fourth != null) {
      return image.Fourth.toString();
    } else if (image.Third != null) {
      return image.Third.toString();
    } else if (image.Second != null) {
      return image.Second.toString();
    } else if (image.First != null) {
      return image.First.toString();
    } else {
      return '';
    }
  }

  // 创建图片存储目录
  String _createImageDirectory(String baseDir, ImageModel image) {
    final levels = [
      image.First,
      image.Second,
      image.Third,
      image.Fourth,
      image.Fifth,
    ];

    // Filter out null values and sanitize directory names
    final validLevels = levels
        .where((level) => level != null)
        .map((level) => level!.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'))
        .toList();

    // Create the full path by joining all components
    var fullPath = baseDir;
    for (final level in validLevels) {
      fullPath = path.join(fullPath, level);
    }

    return fullPath;
  }

  // 下载图片
  Future<void> _downloadImage(ImageModel image, String dirPath) async {
    try {
      final imageUrl = '$_baseUrl/img/${image.imgPath}';
      final uri = Uri.tryParse(imageUrl);

      if (uri == null) throw Exception('无效的图片URL');

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final filePath = path.join(dirPath, image.imgName);
      await File(filePath).writeAsBytes(response.bodyBytes);
    } catch (e) {
      rethrow;
    }
  }

  // 更新图片信息文件
  Future<void> _updateImageInfoFile(ImageModel image, String dirPath) async {
    final jsonFile = File(path.join(dirPath, '${_getJsonName(image)}.json'));
    List<Map<String, dynamic>> images = [];

    if (jsonFile.existsSync()) {
      final data = await jsonFile.readAsString();
      try {
        images = List<Map<String, dynamic>>.from(json.decode(data));
      } catch (e) {
        _addLog('JSON解析错误: ${e.toString()}', success: false);
      }
    }

    // 添加新图片信息
    images.add({
      'First': image.First,
      'Second': image.Second,
      'Third': image.Third,
      'Img_name': image.imgName,
      'Img_path': image.imgPath,
      'China_element_name': image.chinaElementName,
      'caption': image.caption,
      // ... 添加其他需要的字段
    });
    String jsonStr = JsonEncoder.withIndent('  ').convert(images);
    // 写入文件
    await jsonFile.writeAsString(jsonStr, flush: true);
  }

  // 取消导出
  void _cancelExport() {
    setState(() {
      _exportCanceled = true;
      _isExporting = false;
    });
    _addLog('导出已取消');
  }

  // 添加日志条目
  void _addLog(String message, {bool success = true}) {
    final entry = {
      'message': message,
      'success': success,
      'timestamp': DateTime.now().toString().substring(11, 19),
    };
    setState(() {
      _exportLog.insert(0, entry);
      if (_exportLog.length > 50) _exportLog.removeLast();
    });
  }

  // 显示错误消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    _addLog(message, success: false);
  }

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
