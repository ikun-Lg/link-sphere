import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:link_sphere/services/api_service.dart';
import 'product_detail_page.dart';

class SearchProductResultPage extends StatefulWidget {
  final String keyword;

  const SearchProductResultPage({
    super.key,
    required this.keyword,
  });

  @override
  State<SearchProductResultPage> createState() => _SearchProductResultPageState();
}

class _SearchProductResultPageState extends State<SearchProductResultPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> productResults = [];
  bool isLoading = false;
  int lastId = 0; // 用于分页
  static const int pageSize = 10;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.keyword;
    lastId = 0; // 确保初始化时 lastId 为 0
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await _apiService.queryProductList(
        productName: _searchController.text,
        lastId: lastId,
        pageSize: pageSize,
      );

      if (response['code'] == 'SUCCESS_0000' && response['data'] != null) {
        final List<dynamic> products = response['data']['list'] as List<dynamic>;
        setState(() {
          // 修改这里：根据是否是加载更多来决定是追加还是替换数据
          if (lastId == 0) {
            productResults = products.map((item) => item as Map<String, dynamic>).toList();
          } else {
            productResults.addAll(products.map((item) => item as Map<String, dynamic>).toList());
          }
          if (products.isNotEmpty) {
            lastId = products.last['id'] as int;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
          child: _buildSearchField(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  // 滚动到底部时加载更多
                  _performSearch();
                  return true;
                }
                return false;
              },
              child: _buildProductGrid(),
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
              // Expanded(
              //   child: Image.network(
              //     product['mainImage'],
              //     fit: BoxFit.cover,
              //     width: double.infinity,
              //   ),
              // ),
              Expanded(
                child: Image.network(
                 "https://chat-sociality.oss-cn-beijing.aliyuncs.com/2025/04/20/df3d3c04-5a26-4a2b-9b2a-819ea0c75ae2.jpg",
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
                      '${product['sales']}人付款',
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
            '未找到相关商品',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 修改 TextField 的 onChanged 处理
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        hintText: '搜索商品',
        hintStyle: TextStyle(color: Colors.grey[600]),
        suffixIcon: IconButton(
          icon: Icon(Icons.search, color: Colors.grey[600]),
          onPressed: _performSearch,
        ),
      ),
      style: TextStyle(color: Colors.grey[800]),
      onSubmitted: (_) {
        lastId = 0; // 搜索时重置 lastId
        _performSearch();
      },
      onChanged: (value) {
        setState(() {
          lastId = 0; // 输入变化时重置 lastId
        });
      },
    );
  }
}
