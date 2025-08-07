import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/model/tree_node.dart';
import 'package:image_process/user_session.dart';
import 'package:image_process/widget/image_detail.dart';

class GetImageRepetSamplePage extends StatefulWidget {
  const GetImageRepetSamplePage({super.key});

  @override
  State<StatefulWidget> createState() => GetImageRepetSamplePageState();
}

class GetImageRepetSamplePageState extends State<GetImageRepetSamplePage> {
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

  List<TreeNode> _titleTree = [];

  int _currentPage = 1;
  int _limit = 100;

  List<ImageModel> _images = [];
  bool _isImagesLoading = false;
  bool _hasMore = false;
  int _totalItems = 0;

  // 添加变量控制加载状态
  bool _isLoadingAll = false;

  final String baseUrl = UserSession().baseUrl;
  final String token = UserSession().token ?? '';

  // 新添加的变量
  List<MapEntry<int, List<ImageModel>>> _groupedImages = []; // 分组结果
  bool _isComputing = false; // 是否正在计算哈希

  @override
  void initState() {
    super.initState();
    _loadTitleTree();
  }

  // 添加查询重复按钮
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 标题选择器
          _buildTitleSelector(),

          // 添加查询重复按钮
          // 修改按钮的onPressed逻辑
          ElevatedButton.icon(
            onPressed: !_isLoadingAll && !_isComputing
                ? _findSimilarImages
                : null,
            icon: const Icon(Icons.search),
            label: const Text('查询重复图片'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),

          // 显示加载状态
          if (_isComputing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),

          // 显示分组结果
          if (_groupedImages.isNotEmpty)
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "发现 ${_groupedImages.length} 组相似图片",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  ..._buildSimilarGroups(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> handleImageUpdated(ImageModel updatedImage) async {
    if (!mounted) return;

    setState(() {
      // 1. 更新主图片列表
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
      }

      // 2. 更新分组中的图片
      _groupedImages = _groupedImages.map((group) {
        final updatedGroup = group.value
            .map(
              (img) => img.imageID == updatedImage.imageID ? updatedImage : img,
            )
            .toList();
        return MapEntry(group.key, updatedGroup);
      }).toList();

      // 3. 可选：如果需要重新计算分组
      // _recalculateGroupsWithUpdatedImage(updatedImage);
    });
  }

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

  // 构建相似图片分组
  List<Widget> _buildSimilarGroups() {
    return _groupedImages.map((group) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: Text(
                  "相似组 (${group.value.length}张)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                childAspectRatio: 0.7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                padding: const EdgeInsets.all(8.0),
                children: group.value.map((image) {
                  final isAbandoned = image.state == ImageState.Abandoned;
                  return GestureDetector(
                    onTap: () => _showImageDetail(image),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  '$baseUrl/img/${image.imgPath}',
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                image.chinaElementName ?? '未命名',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'ID: ${image.imageID}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (isAbandoned)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.red.withOpacity(0.4),
                              ),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 40,
                                    color: Colors.white,
                                  ),
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
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // 修改后的查找相似图片方法
  Future<void> _findSimilarImages() async {
    setState(() {
      _images.clear();
      _groupedImages.clear();
    });

    if (_images.isEmpty) {
      // 如果没有图片，先加载所有图片
      await _loadAllImages();
    }

    // 如果加载后还是没有图片，显示提示
    if (_images.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有找到符合条件的图片')));
      }
      return;
    }

    // 显示计算哈希的对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: ValueNotifier<int>(_groupedImages.length),
              builder: (context, count, _) {
                return Text('已发现 $count 组相似图片...');
              },
            ),
          ],
        ),
      ),
    );

    try {
      setState(() => _isComputing = true);

      // 第一步：使用差值哈希快速过滤
      final dHashResults = await _computeAllDHashes();
      final dHashGroups = _groupByFastHash(dHashResults, threshold: 5);

      // 第二步：在差值哈希分组内使用均值哈希过滤
      final aHashGroups = <List<ImageModel>>[];
      for (final group in dHashGroups) {
        final aHashResults = await _computeAHashesForImages(group);
        final aHashSubGroups = _groupByFastHash(aHashResults, threshold: 5);
        aHashGroups.addAll(aHashSubGroups);
      }

      // 第三步：在均值哈希分组内使用感知哈希精确匹配
      final pHashGroups = <MapEntry<int, List<ImageModel>>>[];
      for (final group in aHashGroups) {
        if (group.length > 1) {
          // 只有多张图片才需要进一步处理
          final pHashResults = await _computePHashesForImages(group);
          final pHashSubGroups = _groupByPerceptualHash(
            pHashResults,
            threshold: 3,
          );
          pHashGroups.addAll(pHashSubGroups);
        }
      }

      // 合并最终分组
      setState(() => _groupedImages = pHashGroups);
    } finally {
      if (mounted) {
        Navigator.pop(context); // 关闭对话框
        setState(() => _isComputing = false);
      }
    }
  }

  // 新增：计算所有图片的差值哈希
  Future<Map<ImageModel, int>> _computeAllDHashes() async {
    final Map<ImageModel, int> hashes = {};

    for (final image in _images) {
      try {
        final hash = await _computeDHash('$baseUrl/img/${image.imgPath}');
        hashes[image] = hash;
      } catch (e) {
        debugPrint('差值哈希计算失败: $e');
      }
    }

    return hashes;
  }

  // 新增：计算指定图片的均值哈希
  Future<Map<ImageModel, int>> _computeAHashesForImages(
    List<ImageModel> images,
  ) async {
    final Map<ImageModel, int> hashes = {};

    for (final image in images) {
      try {
        final hash = await _computeAHash('$baseUrl/img/${image.imgPath}');
        hashes[image] = hash;
      } catch (e) {
        debugPrint('均值哈希计算失败: $e');
      }
    }

    return hashes;
  }

  // 新增：计算指定图片的感知哈希
  Future<Map<ImageModel, int>> _computePHashesForImages(
    List<ImageModel> images,
  ) async {
    final Map<ImageModel, int> hashes = {};

    for (final image in images) {
      try {
        final hash = await _computeImageHash('$baseUrl/img/${image.imgPath}');
        hashes[image] = hash;
      } catch (e) {
        debugPrint('感知哈希计算失败: $e');
      }
    }

    return hashes;
  }

  // 快速哈希分组方法（用于dHash和aHash）
  List<List<ImageModel>> _groupByFastHash(
    Map<ImageModel, int> hashes, {
    int threshold = 2,
  }) {
    final groups = <int, List<ImageModel>>{};

    // 按哈希值分组
    for (final entry in hashes.entries) {
      final image = entry.key;
      final hash = entry.value;

      bool added = false;
      for (final key in groups.keys) {
        if (_hammingDistance(key, hash) <= threshold) {
          groups[key]!.add(image);
          added = true;
          break;
        }
      }

      if (!added) {
        groups[hash] = [image];
      }
    }

    // 返回所有分组（包括单张图片的分组）
    return groups.values.toList();
  }

  // 新增：感知哈希分组方法
  List<MapEntry<int, List<ImageModel>>> _groupByPerceptualHash(
    Map<ImageModel, int> hashes, {
    int threshold = 3,
  }) {
    final groups = <int, List<ImageModel>>{};

    // 按哈希值分组
    for (final entry in hashes.entries) {
      final image = entry.key;
      final hash = entry.value;

      bool added = false;
      for (final key in groups.keys) {
        if (_hammingDistance(key, hash) <= threshold) {
          groups[key]!.add(image);
          added = true;
          break;
        }
      }

      if (!added) {
        groups[hash] = [image];
      }
    }

    // 过滤掉只有一个图片的分组
    return groups.entries.where((entry) => entry.value.length > 1).toList();
  }

  // 计算所有图片的哈希值
  Future<Map<ImageModel, int>> _computeAllHashes() async {
    final Map<ImageModel, int> hashes = {};

    for (final image in _images) {
      try {
        final hash = await _computeImageHash('$baseUrl/img/${image.imgPath}');
        hashes[image] = hash;
      } catch (e) {
        // 忽略错误图片
        debugPrint('Image hash computation failed: $e');
      }
    }

    return hashes;
  }

  // 修改后的感知哈希计算方法
  Future<int> _computeImageHash(String imageUrl) async {
    try {
      // 加载图像
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('图片加载失败');

      // 使用image包解码图像
      final originalImage = img.decodeImage(response.bodyBytes);
      if (originalImage == null) throw Exception('图片解码失败');

      // 1. 缩小图像尺寸至32x32（保持宽高比）
      final resizedImage = img.copyResize(
        originalImage,
        width: 32,
        height: 32,
        interpolation: img.Interpolation.average,
      );

      // 2. 转换为灰度图
      final grayImage = img.grayscale(resizedImage);

      // 3. 获取32x32像素的灰度值
      final List<double> pixels = [];
      for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
          final pixel = grayImage.getPixel(x, y);
          // 使用Luma方法计算灰度值 (YCbCr)
          final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          pixels.add(gray);
        }
      }

      // 4. 应用DCT变换
      final dctMatrix = _applyDCT(pixels);

      // 5. 提取左上角8x8区域的DCT系数
      final List<double> dctValues = [];
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          dctValues.add(dctMatrix[y][x]);
        }
      }

      // 6. 计算中位值
      final sortedValues = List<double>.from(dctValues)..sort();
      final median = sortedValues[32]; // 64个值的中位值

      // 7. 生成感知哈希值
      int hash = 0;
      for (int i = 0; i < 64; i++) {
        if (dctValues[i] > median) {
          hash |= (1 << i);
        }
      }

      return hash;
    } catch (e) {
      debugPrint('感知哈希计算失败: $e');
      return 0; // 返回默认哈希值
    }
  }

  // 应用二维DCT变换
  List<List<double>> _applyDCT(List<double> pixels) {
    const n = 32;
    final output = List.generate(n, (_) => List<double>.filled(n, 0));

    for (int u = 0; u < n; u++) {
      for (int v = 0; v < n; v++) {
        double sum = 0;

        for (int x = 0; x < n; x++) {
          for (int y = 0; y < n; y++) {
            final cu = (u == 0) ? 1 / math.sqrt(2) : 1;
            final cv = (v == 0) ? 1 / math.sqrt(2) : 1;

            final angleX = (2 * x + 1) * u * math.pi / (2 * n);
            final angleY = (2 * y + 1) * v * math.pi / (2 * n);

            sum +=
                pixels[y * n + x] *
                math.cos(angleX) *
                math.cos(angleY) *
                cu *
                cv;
          }
        }

        output[u][v] = sum / 4;
      }
    }

    return output;
  }

  // 计算差值哈希（dHash）
  Future<int> _computeDHash(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('图片加载失败');

      final originalImage = img.decodeImage(response.bodyBytes);
      if (originalImage == null) throw Exception('图片解码失败');

      // 1. 缩小图像至9x8（宽9高8）
      final resizedImage = img.copyResize(
        originalImage,
        width: 9,
        height: 8,
        interpolation: img.Interpolation.average,
      );

      // 2. 转换为灰度图
      final grayImage = img.grayscale(resizedImage);

      // 3. 计算每行相邻像素的差值
      int hash = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final leftPixel = grayImage.getPixel(x, y);
          final rightPixel = grayImage.getPixel(x + 1, y);

          final leftGray =
              0.299 * leftPixel.r + 0.587 * leftPixel.g + 0.114 * leftPixel.b;
          final rightGray =
              0.299 * rightPixel.r +
              0.587 * rightPixel.g +
              0.114 * rightPixel.b;

          if (leftGray > rightGray) {
            hash |= (1 << (y * 8 + x));
          }
        }
      }

      return hash;
    } catch (e) {
      debugPrint('差值哈希计算失败: $e');
      return 0;
    }
  }

  // 计算均值哈希（aHash）
  Future<int> _computeAHash(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('图片加载失败');

      final originalImage = img.decodeImage(response.bodyBytes);
      if (originalImage == null) throw Exception('图片解码失败');

      // 1. 缩小图像至8x8
      final resizedImage = img.copyResize(
        originalImage,
        width: 8,
        height: 8,
        interpolation: img.Interpolation.average,
      );

      // 2. 转换为灰度图
      final grayImage = img.grayscale(resizedImage);

      // 3. 计算平均灰度值
      double sum = 0;
      final List<double> grays = [];

      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayImage.getPixel(x, y);
          final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          sum += gray;
          grays.add(gray);
        }
      }

      final avg = sum / 64;

      // 4. 生成哈希值
      int hash = 0;
      for (int i = 0; i < 64; i++) {
        if (grays[i] > avg) {
          hash |= (1 << i);
        }
      }

      return hash;
    } catch (e) {
      debugPrint('均值哈希计算失败: $e');
      return 0;
    }
  }

  // 分组相似图片
  void _groupImagesBySimilarity(Map<ImageModel, int> hashes) {
    // 用于分组的数据结构
    final groups = <int, List<ImageModel>>{};

    // 自定义分组逻辑 (汉明距离小于2视为相似)
    const threshold = 2;

    // 首先按哈希值分组
    final initialGroups = hashes.entries.groupListsBy((entry) => entry.value);

    // 进一步合并相似组
    for (final group in initialGroups.values) {
      if (group.isEmpty) continue;

      bool added = false;
      for (final key in groups.keys) {
        if (_hammingDistance(key, group.first.value) <= threshold) {
          groups[key]!.addAll(group.map((e) => e.key));
          added = true;
          break;
        }
      }

      if (!added) {
        groups[group.first.value] = group.map((e) => e.key).toList();
      }
    }

    // 过滤掉只有一个图片的分组
    final validGroups = groups.entries
        .where((entry) => entry.value.length > 1)
        .toList();

    setState(() => _groupedImages = validGroups);
  }

  // 计算汉明距离
  int _hammingDistance(int a, int b) {
    int distance = 0;
    int xor = a ^ b;

    while (xor > 0) {
      distance += xor & 1;
      xor >>= 1;
    }

    return distance;
  }

  // 修改后的获取所有图片方法
  Future<void> _loadAllImages() async {
    setState(() {
      _isLoadingAll = true;
      _isComputing = true;
      _images.clear(); // 清空现有图片
      _currentPage = 0; // 重置页码
      _groupedImages.clear();
    });

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: ValueNotifier<int>(_images.length),
              builder: (context, count, _) {
                return Text('已加载 $count 张图片...');
              },
            ),
          ],
        ),
      ),
    );

    try {
      // 循环加载直到没有更多数据
      while (true) {
        await _fetchAllImages();
        if (!_hasMore) break;
      }
    } finally {
      Navigator.pop(context); // 关闭加载对话框
      setState(() => _isLoadingAll = false);
    }
  }

  // 获取图片
  Future<void> _fetchAllImages() async {
    try {
      final params = {
        'page': (_currentPage + 1).toString(),
        'limit': _limit.toString(),
        if (_selectedLevel1 != null) 'First': _selectedLevel1!,
        if (_selectedLevel2 != null) 'Second': _selectedLevel2!,
        if (_selectedLevel3 != null) 'Third': _selectedLevel3!,
        if (_selectedLevel4 != null) 'Fourth': _selectedLevel4!,
        if (_selectedLevel5 != null) 'Fifth': _selectedLevel5!,
        'goodState': 'true',
      };

      final uri = Uri.parse(
        '$baseUrl/api/image/by-titles',
      ).replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

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
    } catch (e) {
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
        headers: {'Authorization': 'Bearer $token'},
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

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
