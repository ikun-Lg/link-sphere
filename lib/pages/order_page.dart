import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  String? _error;
  int _selectedType = -1;
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchOrders();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    if (currentScroll >= maxScroll * 0.9 && _hasMore) {
      _fetchOrders(isLoadMore: true);
    }
  }

  Future<void> _fetchOrders({bool isLoadMore = false}) async {
    try {
      debugPrint('正在获取类型 $_selectedType 的订单数据');
      final response = await _apiService.getOrders(
        type: _selectedType,
        page: isLoadMore ? _currentPage + 1 : 1,
        size: _pageSize,
      );
      
      if (mounted) {
        setState(() {
          if (response['code'] == 'SUCCESS_0000') {
            final newOrders = response['data']['list'] ?? [];
            final total = response['data']['total'] ?? 0;
            
            // 如果是加载更多，添加到现有列表
            if (isLoadMore) {
              _orders.addAll(newOrders);
              _currentPage++;
            } else {
              // 如果不是加载更多（即刷新或切换类型），替换整个列表
              _orders = newOrders;
              _currentPage = 1;
            }
            
            _hasMore = _orders.length < total;
            _error = null; // 清除之前的错误信息
          } else {
            _error = response['info'] ?? '获取订单失败';
            if (!isLoadMore) {
              _orders = []; // 如果不是加载更多，清空列表
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '获取订单失败: $e';
          if (!isLoadMore) {
            _orders = []; // 如果不是加载更多，清空列表
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的订单'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('全部', -1),
                _buildFilterChip('待付款', 0),
                _buildFilterChip('待发货', 1),
                _buildFilterChip('待收货', 2),
                _buildFilterChip('待评价', 4),
                _buildFilterChip('退款中', 5),
                _buildFilterChip('已退款', 6),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchOrders(),
              child: _orders.isEmpty
                  ? const Center(child: Text('暂无订单'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 商品图片
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    order['mainImage'] ?? '',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // 订单信息
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              order['productName'] ?? '未知商品',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            order['orderStatus'] ?? '未知状态',
                                            style: TextStyle(
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('下单时间：${order['orderTime']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                        '总价：¥${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedType == type,
        onSelected: (bool selected) {
          setState(() {
            _selectedType = selected ? type : -1;
            _orders = [];
            _currentPage = 1;
            _hasMore = true;
          });
          _fetchOrders();
        },
      ),
    );
  }
}