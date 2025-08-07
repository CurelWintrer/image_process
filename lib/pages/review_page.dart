import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_state.dart';
import 'package:image_process/user_session.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<StatefulWidget> createState() => ReviewPageState();
}

class ReviewPageState extends State<ReviewPage> {
  Map<String, dynamic>? statisticsData;
  Map<String, dynamic>? titleTreeData;
  bool isLoading = true;
  String? errorMessage;
  final String? _token = UserSession().token;
  final String? _baseUrl = UserSession().baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final stats = await _fetchStatistics();
      final tree = await _fetchTitleTree();
      if (statisticsData != null && titleTreeData != null) {
        statisticsData!.clear();
        titleTreeData!.clear();
      }
      setState(() {
        statisticsData = stats;
        titleTreeData = tree;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchStatistics() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/image/statistics'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('未授权或token无效');
    } else {
      throw Exception('服务器错误: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _fetchTitleTree() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/image/title-tree'),
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('未授权或token无效');
    } else {
      throw Exception('服务器错误: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text('错误: $errorMessage'));
    }

    return Scaffold(
      body: Column(
        children: [
          // 上部分：整体数据展示
          _buildStatisticsOverview(),
          Divider(height: 20),
          // 下部分：标题树结构
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildTitleTree(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '图片总览',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 700),
              ElevatedButton(
                onPressed: () => _viewAllImages(),
                child: Text('查看全部'),
              ),
              SizedBox(width: 20),
              IconButton(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新数据',
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildStatisticsCards(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final total = statisticsData?['total'] ?? 0;
    final stateCounts =
        statisticsData?['stateCounts'] as Map<String, dynamic>? ?? {};

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('总数', total.toString()),
        ...stateCounts.entries
            .map(
              (e) => _buildStatCard(
                ImageState.getStateText(int.parse(e.key)),
                e.value.toString(),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildStatCard(String title, String count) {
    return Container(
      width: 100,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 14)),
          SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleTree() {
    if (titleTreeData == null || !titleTreeData!['success']) {
      return Center(child: Text('无法加载标题树'));
    }

    final treeList = titleTreeData?['titleTree'] as List<dynamic>? ?? [];

    // 递归构建树形列表
    Widget _buildTreeNodes(List<dynamic> nodes, int level) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: nodes.map<Widget>((node) {
          final title = node['title'] as String? ?? '未命名';
          final children = node['children'] as List<dynamic>? ?? [];
          final titleStats = _findTitleStatistics(title);
          final total = titleStats?['total'] ?? 0;

          // 获取当前层级的颜色
          final levelColor = _getLevelColor(level);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前节点使用Card以增加视觉分割感
              Card(
                color: level == 0
                    ? Colors.blue[50]
                    : Colors.transparent, // 顶层背景色更突出
                margin: EdgeInsets.only(left: level * 20.0, top: 8), // 根据层级缩进
                elevation: level == 0 ? 2 : 0, // 顶层有轻微阴影
                child: InkWell(
                  onTap: () => {},
                  hoverColor: Colors.blue[100], // 桌面端悬停效果
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // 层级指示器
                        Container(
                          width: 6,
                          height: 36,
                          decoration: BoxDecoration(
                            color: levelColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        SizedBox(width: 16),
                        // 标题文本
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: level == 0 ? 18 : 16,
                              fontWeight: level == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: levelColor,
                            ),
                          ),
                        ),
                        // 数量显示 - 靠近标题
                        Container(
                          decoration: BoxDecoration(
                            color: levelColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: levelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 子节点
              if (children.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 20.0),
                  child: _buildTreeNodes(children, level + 1),
                ),
            ],
          );
        }).toList(),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [_buildTreeNodes(treeList, 0)],
    );
  }

  // 根据层级获取不同的颜色
  Color _getLevelColor(int level) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    return colors[level % colors.length];
  }

  

  Map<String, dynamic>? _findTitleStatistics(String title) {
    if (statisticsData == null) return null;

    final titleStats =
        statisticsData!['titleStatistics'] as Map<String, dynamic>?;
    if (titleStats == null) return null;

    // 在一级标题中查找
    final firstLevel = titleStats['First'] as Map<String, dynamic>?;
    if (firstLevel != null && firstLevel.containsKey(title)) {
      return firstLevel[title];
    }

    // 在二级标题中查找（可根据需要添加更多层级）
    final secondLevel = titleStats['Second'] as Map<String, dynamic>?;
    if (secondLevel != null && secondLevel.containsKey(title)) {
      return secondLevel[title];
    }

    final thirdLevel = titleStats['Third'] as Map<String, dynamic>?;
    if (thirdLevel != null && thirdLevel.containsKey(title)) {
      return thirdLevel[title];
    }

    final fourthLevel = titleStats['Fourth'] as Map<String, dynamic>?;
    if (fourthLevel != null && fourthLevel.containsKey(title)) {
      return fourthLevel[title];
    }
    final fifthLevel = titleStats['Fifth'] as Map<String, dynamic>?;
    if (fifthLevel != null && fifthLevel.containsKey(title)) {
      return fifthLevel[title];
    }

    return null;
  }


  void _viewAllImages() {
    Navigator.pushNamed(context, '/allImage');
  }
}
