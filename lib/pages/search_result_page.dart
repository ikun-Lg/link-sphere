import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'post_detail_page.dart';

class SearchResultPage extends StatefulWidget {
  final String keyword;

  const SearchResultPage({
    super.key,
    required this.keyword,
  });

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<Map<String, dynamic>> postResults = [];
  List<Map<String, dynamic>> userResults = [];
  List<Map<String, dynamic>> productResults = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.keyword;
    _tabController = TabController(length: 3, vsync: this);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    // 模拟用户搜索结果
    final List<Map<String, dynamic>> mockUserResults = List.generate(
      5,
      (index) => {
        'id': 'user_$index',
        'name': '用户${widget.keyword}$index',
        'avatar': 'https://picsum.photos/200/200?random=$index',
        'description': '这是用户简介...',
        'followers': 1000 + index * 100,
      },
    );

    // 模拟帖子搜索结果
    final List<Map<String, dynamic>> mockPostResults = List.generate(
      15,
      (index) => {
        'id': 'post_$index',
        'title': '${widget.keyword}相关的帖子 $index',
        'body': '这是一个关于${widget.keyword}的帖子内容...',
        'imageUrl': 'https://picsum.photos/300/400?random=$index',
        'author': '用户$index',
        'likes': 100 + index,
        'comments': 20 + index,
      },
    );

    // 模拟商品搜索结果
    final List<Map<String, dynamic>> mockProductResults = List.generate(
      10,
      (index) => {
        'id': 'product_$index',
        'name': '${widget.keyword}商品 $index',
        'price': 99.9 + index * 10,
        'imageUrl': 'https://picsum.photos/300/300?random=$index',
        'shop': '店铺$index',
        'sales': 1000 + index * 50,
      },
    );

    setState(() {
      userResults = mockUserResults;
      postResults = mockPostResults;
      productResults = mockProductResults;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: Colors.grey[200], // 修改为浅灰色背景
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              hintText: '搜索',
              hintStyle: TextStyle(color: Colors.grey[600]), // 修改提示文字颜色
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: Colors.grey[600]), // 修改搜索图标颜色
                onPressed: _performSearch,
              ),
            ),
            style: TextStyle(color: Colors.grey[800]), // 修改输入文字颜色
            onSubmitted: (_) => _performSearch(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '用户'),
            Tab(text: '帖子'),
            Tab(text: '商品'),
          ],
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Colors.black87, // 修改选中标签颜色
          unselectedLabelColor: Colors.grey[600], // 修改未选中标签颜色
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(),
                _buildPostGrid(),
                _buildProductGrid(),
              ],
            ),
    );
  }

  Widget _buildUserList() {
    if (userResults.isEmpty) {
      return _buildEmptyView();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: userResults.length,
      itemBuilder: (context, index) {
        final user = userResults[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatar'] as String),
            ),
            title: Text(user['name'] as String),
            subtitle: Text(user['description'] as String),
            trailing: Text('${user['followers']}关注'),
            onTap: () {
              // TODO: 跳转到用户主页
            },
          ),
        );
      },
    );
  }

  Widget _buildPostGrid() {
    if (postResults.isEmpty) {
      return _buildEmptyView();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: postResults.length,
        itemBuilder: (context, index) {
          final post = postResults[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailPage(
                    postId: post['id'].toString(),
                  ),
                ),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    post['imageUrl'] as String,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                'https://picsum.photos/50/50?random=${post['id']}',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post['author'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (productResults.isEmpty) {
      return _buildEmptyView();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: productResults.length,
      itemBuilder: (context, index) {
        final product = productResults[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Image.network(
                  product['imageUrl'] as String,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${product['price']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product['shop']} · ${product['sales']}人付款',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '未找到相关内容',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}