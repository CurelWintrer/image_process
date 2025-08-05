import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/title_type.dart';
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

  @override
  void initState() {
    super.initState();
    fetchTitleTypes();
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
      appBar: AppBar(title: Text('导出图片')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleSelectors(),
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

  // 构建多级标题选择器
  Widget _buildTitleSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLevelSelector('一级标题', 'First'),
        _buildLevelSelector('二级标题', 'Second'),
        _buildLevelSelector('三级标题', 'Third'),
        _buildLevelSelector('四级标题', 'Fourth'),
        _buildLevelSelector('五级标题', 'Fifth'),
      ],
    );
  }

  Widget _buildLevelSelector(String label, String level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$label:')),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedTitles[level],
              hint: const Text('未选择'),
              items: _getDropdownItems(level),
              onChanged: (value) =>
                  setState(() => selectedTitles[level] = value),
            ),
          ),
        ],
      ),
    );
  }

  // 获取下拉菜单选项
  List<DropdownMenuItem<String>>? _getDropdownItems(String level) {
    final levelData = {
      'First': titleTypes?.first,
      'Second': titleTypes?.second,
      'Third': titleTypes?.third,
      'Fourth': titleTypes?.fourth,
      'Fifth': titleTypes?.fifth,
    }[level];

    return levelData
        ?.map<DropdownMenuItem<String>>(
          (value) => DropdownMenuItem(value: value, child: Text(value)),
        )
        .toList();
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
    // 验证至少选择了一个标题
    if (selectedTitles.values.every((value) => value == null)) {
      _showError('请至少选择一个标题');
      return;
    }

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
          'goodState':'true',
          ...selectedTitles.map((k, v) => MapEntry(k, v)),
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

  String _getJsonName(ImageModel image){
    if(image.Fifth!=null){
      return image.Fifth.toString();
    }else if(image.Fourth!=null){
      return image.Fourth.toString();
    }else if(image.Third!=null){
      return image.Third.toString();
    }else if(image.Second!=null){
      return image.Second.toString();
    }else if(image.First!=null){
      return image.First.toString();
    }else{
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
}
