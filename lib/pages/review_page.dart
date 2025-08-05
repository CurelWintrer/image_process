import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '图片总览',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () => _viewAllImages(),
                child: Text('查看全部'),
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
              (e) => _buildStatCard(_getStateName(e.key), e.value.toString()),
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
    return ListView.builder(
      itemCount: treeList.length,
      itemBuilder: (context, index) {
        return _buildTreeNode(treeList[index]);
      },
    );
  }

  Widget _buildTreeNode(dynamic nodeData) {
    final title = nodeData['title'] as String? ?? '未命名';
    final children = nodeData['children'] as List<dynamic>? ?? [];
    final titleStats = _findTitleStatistics(title);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            Chip(
              label: Text('${titleStats?['total'] ?? 0}'),
              backgroundColor: Colors.blue[100],
            ),
          ],
        ),
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: _buildTreeNode(child),
              ),
            )
            .toList(),
      ),
    );
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

    return null;
  }

  String _getStateName(String stateCode) {
    switch (stateCode) {
      case '0':
        return '未检查';
      case '1':
        return '检查中';
      case '3':
        return '审核中';
      case '4':
        return '已通过';
      case '5':
        return '已废弃';
      default:
        return '未知';
    }
  }

  void _viewAllImages() {
    Navigator.pushNamed(context, '/allImage');
  }
}
