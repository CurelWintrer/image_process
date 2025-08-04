import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/user_session.dart';

class TreeNode {
  final int id;
  final String title;
  final List<TreeNode> children;

  TreeNode({required this.id, required this.title, required this.children});

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      id: json['id'],
      title: json['title'],
      children: List<TreeNode>.from(
        json['children']?.map((x) => TreeNode.fromJson(x)) ?? [],
      ),
    );
  }
}

class AllImagePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AllImagePageState();
}

class AllImagePageState extends State<AllImagePage> {
  final String baseUrl = UserSession().baseUrl;
  late String authToken = UserSession().token ?? '';

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
  int _limit = 30;
  bool _isImagesLoading = false;
  int _gridColumnCount = 4;

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
      appBar: AppBar(title: Text('All Image')),
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
        ],
      ),
    );
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
            onPressed:() => {
                    _images.clear(),
                    _totalItems = 0,
                    _currentPage = 0,
                    _hasMore=true,
                    _isImagesLoading=false,
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
    final imageUrl = '$baseUrl/img/${image.imgPath}'; // 构造完整URL

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片显示
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
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
                  image.imgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  image.chinaElementName,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 图片显示组件（使用您实现的组件）
  Widget _buildImageWithFallback(String url) {
    // 这里是您已实现的图片加载组件
    // 示例：使用Image.network并添加错误处理
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
