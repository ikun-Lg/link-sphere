class CategoryNode {
  final int id;
  final String name;
  final int sortOrder;
  final List<CategoryNode> children;
  int depth; // <--- 新增：分类深度

  CategoryNode({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.children,
    this.depth = 0, // <--- 初始化深度为 0
  });

  factory CategoryNode.fromJson(Map<String, dynamic> json) {
    var childrenFromJson = json['children'] as List? ?? [];
    List<CategoryNode> childrenList = childrenFromJson
        .map((childJson) => CategoryNode.fromJson(childJson))
        .toList();

    return CategoryNode(
      id: json['id'] as int? ?? 0, // 提供默认值以防 null
      name: json['name'] as String? ?? '未知分类', // 提供默认值
      sortOrder: json['sortOrder'] as int? ?? 0, // 提供默认值
      children: childrenList,
    );
  }
}