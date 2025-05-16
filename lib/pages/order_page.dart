import 'package:flutter/material.dart';
import 'dart:async';
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

  // 存储每个订单的倒计时定时器
  final Map<String, Timer?> _orderTimers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchOrders();
  }

  @override
  void dispose() {
    // 取消所有倒计时定时器
    _orderTimers.forEach((key, timer) {
      timer?.cancel();
    });
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 计算订单剩余支付时间
  String _calculateRemainingTime(String orderTime) {
    final orderDateTime = DateTime.parse(orderTime);
    final expirationTime = orderDateTime.add(const Duration(minutes: 30));
    final now = DateTime.now();
    final remaining = expirationTime.difference(now);

    if (remaining.isNegative) {
      return '已超时';
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // 启动订单倒计时
  void _startOrderTimer(String orderId, String orderTime) {
    _orderTimers[orderId]?.cancel(); // 取消之前的定时器

    _orderTimers[orderId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remainingTime = _calculateRemainingTime(orderTime);
      if (remainingTime == '已超时') {
        timer.cancel();
        _orderTimers.remove(orderId);
        setState(() {}); // 触发重建以更新UI
      }
    });
  }

  // 显示支付弹窗
  void _showPaymentDialog(dynamic order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('订单支付'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('商品: ${order['productName']}'),
              Text('总价: ¥${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
              const SizedBox(height: 16),
              const Text('请选择支付方式:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // 微信支付逻辑
                      try {
                        final response = await _apiService.createPayOrder(order['productId']);
                        if (response['code'] == 'SUCCESS_0000') {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('支付成功')),
                          );
                          // 刷新订单列表
                          _fetchOrders();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('支付失败: ${response['info']}')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('支付出错: $e')),
                        );
                      }
                    },
                    child: const Text('微信支付'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // 支付宝支付逻辑
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('支付宝支付功能开发中')),
                      );
                    },
                    child: const Text('支付宝支付'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 已移除重复的 dispose 方法

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
                _buildFilterChip('系统关单', 3),
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
                        // 如果是待支付订单，启动倒计时
                        if (order['orderStatus'] == '等待买家付款') {
                          _startOrderTimer(order['orderId'].toString(), order['orderTime']);
                        }

                        return GestureDetector(
                          onTap: () {
                            // 仅对等待买家付款订单弹出支付窗口
                            if (order['orderStatus'] == '等待买家付款') {
                              _showPaymentDialog(order);
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
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
                                  // 添加倒计时显示
                                  if (order['orderStatus'] == '等待买家付款') ...[  
                                    const SizedBox(height: 8),
                                    Text(
                                      '剩余支付时间：${_calculateRemainingTime(order['orderTime'])}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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