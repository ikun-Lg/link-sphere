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
  int _currentPage = 0;
  final int _pageSize = 30;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // 存储每个订单的倒计时定时器
  final Map<String, Timer?> _orderTimers = {};
  // 存储每个订单的剩余时间（秒）
  final Map<String, int> _orderRemainingSeconds = {};

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

  // 获取订单剩余时间
  Future<void> _fetchOrderCountdown(String orderId) async {
    try {
      final response = await _apiService.getOrderCountdown(int.parse(orderId));
      if (response['code'] == 'SUCCESS_0000') {
        final data = response['data'];
        if (mounted) {
          setState(() {
            // 处理 remainingTime 为字符串的情况
            final remainingTimeStr = data['remainingTime'].toString();
            final totalSeconds = int.tryParse(remainingTimeStr) ?? 0;
            _orderRemainingSeconds[orderId] = totalSeconds;
            
            // 如果订单未过期且剩余时间大于0，启动倒计时
            if (!data['expire'] && totalSeconds > 0) {
              _startOrderTimer(orderId);
            } else {
              // 如果订单已过期，取消定时器并刷新列表
              _orderTimers[orderId]?.cancel();
              _orderTimers.remove(orderId);
              _fetchOrders();
            }
          });
        }
      }
    } catch (e) {
      print('获取订单剩余时间失败: $e');
    }
  }

  // 启动订单倒计时
  void _startOrderTimer(String orderId) {
    _orderTimers[orderId]?.cancel(); // 取消之前的定时器

    _orderTimers[orderId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        final currentSeconds = _orderRemainingSeconds[orderId] ?? 0;
        if (currentSeconds > 0) {
          _orderRemainingSeconds[orderId] = currentSeconds - 1;
        } else {
          timer.cancel();
          _orderTimers.remove(orderId);
          // 如果订单过期，刷新订单列表
          _fetchOrders();
        }
      });
    });
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
        page: isLoadMore ? _currentPage + 1 : 0,
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
              _currentPage = 0;
            }
            
            _hasMore = _orders.length < total;
            _error = null; // 清除之前的错误信息

            // 为待付款订单获取剩余时间
            for (var order in _orders) {
              if (order['orderStatus'] == '等待买家付款') {
                _fetchOrderCountdown(order['orderId'].toString());
              }
            }
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

  // --- 新增：显示支付二维码弹窗 ---
  Future<void> _showPaymentQrCodeDialog(String productName, dynamic productId) async {
    try {
      // 确保 productId 是整数类型
      final int productIdInt = int.parse(productId.toString());
      final response = await _apiService.createPayOrder(productIdInt);
      if (response['code'] == 'SUCCESS_0000') {
        final String? qrCodeUrl = response['data'] as String?;
        if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('订单支付'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text('请扫描下方二维码完成对商品 "$productName" 的支付：'),
                      const SizedBox(height: 16),
                      Center(
                        child: Image.network(
                          qrCodeUrl,
                          height: 200,
                          width: 200,
                          fit: BoxFit.contain,
                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                            return const Center(child: Text('二维码加载失败'));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('完成支付'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // 刷新订单列表
                      _fetchOrders();
                    },
                  ),
                ],
              );
            },
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取支付二维码失败')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建支付订单失败: ${response['info']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支付出错: $e')),
      );
    }
  }
  // --- 新增结束 ---

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

                        return GestureDetector(
                          onTap: () {
                            // 如果是待付款状态，点击显示支付二维码
                            if (order['orderStatus'] == '等待买家付款') {
                              _showPaymentQrCodeDialog(
                                order['productName'] ?? '未知商品',
                                order['productId'],
                              );
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '剩余支付时间：${_orderRemainingSeconds[order['orderId'].toString()] ?? 0}s',
                                          style: TextStyle(
                                            color: (_orderRemainingSeconds[order['orderId'].toString()] ?? 0) <= 0 
                                                ? Colors.red 
                                                : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            _showPaymentQrCodeDialog(
                                              order['productName'] ?? '未知商品',
                                              order['productId'],
                                            );
                                          },
                                          child: const Text('立即支付'),
                                        ),
                                      ],
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
            _currentPage = 0;
            _hasMore = true;
          });
          _fetchOrders();
        },
      ),
    );
  }
}