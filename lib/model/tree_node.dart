class TreeNode {
  final int id;
  final String title;
  final List<TreeNode> children;
  final String? remark;

  TreeNode({
    required this.id,
    required this.title,
    required this.children,
    this.remark,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      id: json['id'],
      title: json['title'],
      children: List<TreeNode>.from(
        json['children']?.map((x) => TreeNode.fromJson(x)) ?? [],
      ),
      remark: json['remark'],
    );
  }
}
