import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart'; // <--- 导入 image_picker
import 'package:link_sphere/models/category_node.dart';
import '../models/user.dart';
import 'user_service.dart';
import 'package:link_sphere/utils/network_utils.dart';

class ApiService {
  // 上传头像
  Future<String> uploadAvatar(XFile file) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录';
    }
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      final response = await _dio.post(
        '/user/upload/avatar',
        data: formData,
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data['info']; // 返回图片URL
      }
      throw response.data['info'] ?? '上传头像失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- 新增：获取登录验证码 ---
  Future<Map<String, dynamic>> getVerificationCode({
    required String contactInformation,
    required int type, // 1: 电话, 2: 邮箱
  }) async {
    try {
      final response = await _dio.get(
        '/user/authenticate/code',
        queryParameters: {
          'contactInformation': contactInformation,
          'type': type,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Verification Code Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取验证码失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // --- 新增：获取注册验证码 ---
  Future<Map<String, dynamic>> getRegisterVerificationCode({
    required String contactInformation,
    required int type, // 1: 电话, 2: 邮箱
  }) async {
    try {
      final response = await _dio.get(
        '/user/authenticate/registerCode', // 更新为注册验证码接口
        queryParameters: {
          'contactInformation': contactInformation,
          'type': type,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      print('Get Register Verification Code Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取注册验证码失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://116.198.239.101:8089/api/v1',
      connectTimeout: const Duration(seconds: 30), // 增加到30秒
      receiveTimeout: const Duration(seconds: 30),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          print('API错误: ${e.message}');
          if (e.response?.statusCode == 500) {
            print('服务器内部错误: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ),
    );

  // 新增：对外暴露dio实例
  Dio get dio => _dio;

  // --- 新增：验证Token --- 
  Future<bool> validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/user/test',
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return true; // Token 有效
      }
      return false; // Token 无效
    } catch (e) {
      // 发生任何错误（包括网络错误、DioError等）都视为Token无效或验证失败
      print('Validate token error: $e');
      return false;
    }
  }
  // --- 新增结束 ---

  Future<bool> login({
    required String contactInformation,
    required String passwordCode,
    required int code,
  }) async {
    print('Login Request: $contactInformation, $passwordCode, $code');
    try {
      final response = await _dio.post(
        '/user/authenticate/login',
        data: {
          'contactInformation': contactInformation,
          'passwordCode': passwordCode,
          'code': code,
        },
      );

      print('Login Response: ${response.data}'); // 添加调试日志

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        final userData = response.data['data']; // 获取 data 对象
        final user = User.fromJson(userData); // 使用 User.fromJson 解析
        await UserService.saveUser(user); // 保存 User 对象
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    print('处理API错误: ${error.type}, message: ${error.message}');
    print('响应状态码: ${error.response?.statusCode}');
    print('响应数据: ${error.response?.data}');
    
    // 使用通用的错误处理工具
    return NetworkUtils.handleApiError(error);
  }
  
  // 搜索用户
  Future<Map<String, dynamic>> searchUsers({
    required String keywords,
    int page = 1,
    int size = 10,
  }) async {
    try {
      final token = await UserService.getToken();
      // 构建queryParameters，避免传递null
      final Map<String, dynamic> queryParameters = {
        'page': page,
        'size': size,
      };
      if (keywords.isNotEmpty) {
        queryParameters['keywords'] = keywords;
      }
      final response = await _dio.get(
        '/user/search',
        queryParameters: queryParameters,
        options: Options(
          headers: token != null ? {'Authorization': token} : {},
        ),
      );
      
      print('Search Users Response: ${response.data}');
      
      if (response.statusCode == 200) {
        return response.data;
      }
      throw response.data['info'] ?? '搜索用户失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> register({
    required String contactInformation,
    required String code, // 修改：之前是 passwordCode
    required String type, // 修改：之前是 int code, 现在是 String type
  }) async {
    print('Register Request: contactInformation: $contactInformation, code: $code, type: $type');
    try {
      final response = await _dio.post(
        '/user/authenticate/register', // 修改：更新API端点
        data: {
          'contactInformation': contactInformation,
          'code': code, // 修改：参数名和值
          'type': type, // 修改：参数名和值
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      print('Register Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        // 注册成功，根据接口定义，data为null，不需要保存用户信息或token
        return true;
      }
      // 如果code不是SUCCESS_0000，则抛出info中的错误信息
      throw response.data['info'] ?? '注册失败: 未知错误';
    } on DioException catch (e) {
      // 处理Dio相关的网络错误等
      if (e.response != null && e.response!.data != null && e.response!.data['info'] != null) {
        throw e.response!.data['info'];
      }
      throw _handleError(e);
    } catch (e) {
      // 处理其他类型的错误，例如上面抛出的字符串错误
      print('Register error: $e');
      throw e.toString();
    }
  }

  // 获取二级评论列表的方法
  Future<List<dynamic>> getSecondLevelComments({
    required int parentId,
    int? lastId,
    String? token,
  }) async {
    try {
      final options = Options(
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': token,
        },
      );

      final queryParams = <String, dynamic>{};
      if (lastId != null) {
        queryParams['lastId'] = lastId;
      }

      final response = await _dio.get(
        '/comments/$parentId/reply/list',
        queryParameters: queryParams,
        options: options,
      );

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data['data'] ?? [];
      }
      throw response.data['info'] ?? '获取二级评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取作者自己帖子列表
  Future<Map<String, dynamic>> getAuthorPosts({int page = 1, int size = 10}) async { // 添加 page 和 size 参数
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.get(
        '/posts/author/list', // API路径保持不变
        queryParameters: {'page': page, 'size': size}, // 添加分页查询参数
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500; // 添加状态码验证
          },
        ),
      );

      print('API Response (Page $page): ${response.data}'); // 添加调试日志

      if (response.statusCode == 200) {
        // --- 修改：返回包含分页信息的 data ---
        // 后端返回的数据结构可能需要调整，这里假设后端直接返回列表在 'data' 下
        // 如果后端返回了分页信息 (如 total, pages)，则需要相应处理
        // 暂时假设后端直接返回列表，需要在 ProfilePage 处理分页逻辑
        return response.data;
        // --- 修改结束 ---
      }
      // --- 修改：调整错误抛出逻辑以匹配新的返回结构 ---
      throw '获取帖子失败：${response.data['info'] ?? response.statusMessage ?? '未知错误'}';
      // --- 修改结束 ---
    } on DioException catch (e) {
      print('API Error: ${e.message}'); // 添加错误日志
      print('Request: ${e.requestOptions.uri}'); // 打印请求URL
      print('Response: ${e.response?.data}'); // 打印响应数据
      throw _handleError(e);
    }
  }

  // 获取首页帖子列表
  Future<Map<String, dynamic>> getHomePosts({
    int page = 1,
    int size = 10,
    String type = 'latest',
  }) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    try {
      // 如果是热门，调用推荐接口 (getRecommendPosts 内部会处理 token)
      if (type == 'hot') {
        return await getRecommendPosts(topN: size);
      }
      print('object');
      // 否则调用普通列表接口
      final response = await _dio.get(
        '/posts/list',
        queryParameters: {'page': page, 'size': size},
        options: Options(
          headers: {
            // 添加 Authorization 头
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // 打印响应数据，帮助调试
        print('获取帖子响应: ${response.data}');
        return response.data;
      }
      throw '获取帖子失败：${response.data['message'] ?? '未知错误'}';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取推荐帖子列表
  Future<Map<String, dynamic>> getRecommendPosts({int topN = 10}) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.get(
        '/recommend/user/content',
        queryParameters: {'topN': topN},
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // 处理推荐接口的特殊响应格式
        if (response.data['code'] == 'SUCCESS_0000') {
          return {
            'code': response.data['code'],
            'info': response.data['info'],
            'data': {
              'list': response.data['data'], // 将推荐数据转换为与普通列表相同的格式
            },
          };
        }
        return response.data;
      }
      throw '获取推荐帖子失败：${response.data['message'] ?? '未知错误'}';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取帖子详情
  Future<Map<String, dynamic>> getPostDetail(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    try {
      final response = await _dio.get(
        '/posts/$postId',
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        print('Post Detail Response: ${response.data}');
        return response.data; // 返回整个响应数据，而不是只返回 data 字段
      }
      throw response.data['info'] ?? '获取帖子详情失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取用户基本信息
  Future<Map<String, dynamic>> getUserInfo(int? userId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    
    try {
      final response = await _dio.get(
        '/user/info/$userId', // 使用路径参数
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '', 
            'Accept': 'application/json',
          },
        ),
      );

      print('Get User Info Response for $userId: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data; // 返回整个响应数据
      }
      throw response.data['info'] ?? '获取用户信息失败';
    } on DioException catch (e) {
      // 可以根据需要处理特定错误，例如 404 用户不存在
      if (e.response?.statusCode == 404) {
         print('User not found (404)');
         throw '用户不存在';
      }
      throw _handleError(e);
    }
  }

  // 关注用户
  Future<Map<String, dynamic>> followUser(String userId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.post(
        '/user/follow',
        data: {'userId': userId},
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Follow User Response: ${response.data}'); // 添加调试日志

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '关注失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 取消关注用户
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.post(
        '/user/unfollow',
        data: {'userId': userId},
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Unfollow User Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '取消关注失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 收藏帖子
  Future<Map<String, dynamic>> collectPost(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.post(
        '/posts/collect/$postId',
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Collect Post Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 假设后端在已收藏时返回特定错误码或信息，需要根据实际情况调整
      if (response.data['code'] == 'ALREADY_COLLECTED_ERROR_CODE') {
        // 示例错误码
        return {
          'code': 'SUCCESS_0000',
          'info': '已收藏',
          'data': '操作成功',
        }; // 模拟成功，避免前端报错
      }
      throw response.data['info'] ?? '收藏失败';
    } on DioException catch (e) {
      // 处理可能的冲突，例如帖子已被收藏
      if (e.response?.statusCode == 409) {
        // 假设 409 Conflict 表示已收藏
        print('Post already collected (assumed from 409 Conflict)');
        return {'code': 'SUCCESS_0000', 'info': '已收藏', 'data': '操作成功'}; // 模拟成功
      }
      throw _handleError(e);
    }
  }

  // 取消收藏帖子 (更新为 POST /posts/unCollect/{postId})
  Future<Map<String, dynamic>> uncollectPost(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      // 使用 POST 方法和新的路径 /posts/unCollect/{postId}
      final response = await _dio.post(
        '/posts/unCollect/$postId', // 更新路径
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Uncollect Post Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 假设后端在未收藏时返回特定错误码或信息
      if (response.data['code'] == 'NOT_COLLECTED_ERROR_CODE') {
        // 示例错误码
        return {'code': 'SUCCESS_0000', 'info': '未收藏', 'data': '操作成功'}; // 模拟成功
      }
      throw response.data['info'] ?? '取消收藏失败';
    } on DioException catch (e) {
      // 处理可能的错误，例如帖子未被收藏
      if (e.response?.statusCode == 404) {
        // 假设 404 Not Found 表示未收藏
        print('Post not collected (assumed from 404 Not Found)');
        return {'code': 'SUCCESS_0000', 'info': '未收藏', 'data': '操作成功'}; // 模拟成功
      }
      throw _handleError(e);
    }
  }

  // 点赞帖子
  Future<Map<String, dynamic>> likePost(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.post(
        '/posts/like/$postId', // 点赞接口路径
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Like Post Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 可以根据后端实际返回的错误码处理已点赞的情况
      // if (response.data['code'] == 'ALREADY_LIKED_CODE') {
      //   return {'code': 'SUCCESS_0000', 'info': '已点赞', 'data': null}; // 模拟成功
      // }
      throw response.data['info'] ?? '点赞失败';
    } on DioException catch (e) {
      // 可以根据状态码处理已点赞的情况，例如 409 Conflict
      // if (e.response?.statusCode == 409) {
      //   print('Post already liked (assumed from 409 Conflict)');
      //   return {'code': 'SUCCESS_0000', 'info': '已点赞', 'data': null}; // 模拟成功
      // }
      throw _handleError(e);
    }
  }

  // 取消点赞帖子
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.post(
        '/posts/unlike/$postId', // 取消点赞接口路径
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Unlike Post Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 可以根据后端实际返回的错误码处理未点赞的情况
      // if (response.data['code'] == 'NOT_LIKED_CODE') {
      //   return {'code': 'SUCCESS_0000', 'info': '未点赞', 'data': null}; // 模拟成功
      // }
      throw response.data['info'] ?? '取消点赞失败';
    } on DioException catch (e) {
      // 可以根据状态码处理未点赞的情况，例如 404 Not Found
      // if (e.response?.statusCode == 404) {
      //   print('Post not liked (assumed from 404 Not Found)');
      //   return {'code': 'SUCCESS_0000', 'info': '未点赞', 'data': null}; // 模拟成功
      // }
      throw _handleError(e);
    }
  }

  // 获取用户收藏的帖子列表
  Future<Map<String, dynamic>> getCollectedPosts(String userId, {int page = 1, int size = 10}) async { // 添加 page 和 size 参数
    // 尝试获取 token
    final token = await UserService.getToken();
    // 不再需要检查 token 是否为 null 并抛出异常

    try {
      final response = await _dio.get(
        '/posts/collect/list/$userId', // 确认 API 路径是否正确，通常列表是 /posts/collect/list 或类似
        queryParameters: {'page': page, 'size': size}, // 添加分页查询参数
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500; // 添加状态码验证
          },
        ),
      );

      print('Collected Posts API Response (Page $page): ${response.data}'); // 添加调试日志

      if (response.statusCode == 200) {
        // 假设后端返回的数据结构与 getAuthorPosts 类似
        return response.data;
      }
      throw '获取收藏帖子失败：${response.data['info'] ?? response.statusMessage ?? '未知错误'}';
    } on DioException catch (e) {
      print('Collected Posts API Error: ${e.message}'); // 添加错误日志
      print('Request: ${e.requestOptions.uri}'); // 打印请求URL
      print('Response: ${e.response?.data}'); // 打印响应数据
      throw _handleError(e);
    }
  }

  // 获取用户点赞的帖子列表
  Future<Map<String, dynamic>> getLikedPosts(String userId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    try {
      final response = await _dio.get(
        '/posts/like/list/$userId', // API 路径
        options: Options(
          headers: {
            // 如果 token 为 null，则传递空字符串，否则传递 token
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Liked Posts Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        // --- 修改：直接返回 API 的响应数据 ---
        return response.data;
        // --- 修改结束 ---
      }
      // --- 修改：调整错误抛出逻辑以匹配新的返回结构 ---
      throw response.data['info'] ?? '获取点赞列表失败';
      // --- 修改结束 ---
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取最新帖子
  Future<Map<String, dynamic>> getLatestPosts({
    String? keywords,
    int page = 1,
    int size = 10,
  }) async {
    final token = await UserService.getToken();
    try {
      final response = await _dio.get(
        '/posts/search',
        queryParameters: {
          'keyword': keywords,
          'page': page,
          'size': size
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': token,
          }
        ),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      throw response.data['info'] ?? '获取最新帖子失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取推荐帖子
  Future<Map<String, dynamic>> getRecommendedPosts({
    String? keywords,
    int topN = 10,
  }) async {
    final token = await UserService.getToken();
    try {
      final response = await _dio.get(
        '/recommend/search/content',
        queryParameters: {
          'keywords': keywords,
          'topN': topN
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': token,
          }
        ),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      throw response.data['info'] ?? '获取推荐帖子失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 搜索商品
  Future<Map<String, dynamic>> searchProducts({
    required String keywords,
    int page = 1,
    int size = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/sale/search_product',
        queryParameters: {
          'keywords': keywords,
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      // 首先检查响应数据是否是 Map
      if (response.data is Map) {
        final responseData = response.data as Map<String, dynamic>;
        // 检查业务码是否成功
        if (response.statusCode == 200 && responseData['code'] == 'SUCCESS_0000') {
          return responseData; // 成功，返回整个响应体
        } else {
          // 业务失败或其他错误码，抛出 info
          throw responseData['info'] ?? '搜索商品失败: 未知业务错误';
        }
      }
      // 如果响应数据不是 Map，或者状态码不是200 (且未被DioException捕获)
      throw '搜索商品失败: 响应格式不正确或网络错误 ${response.statusCode}';
    } on DioException catch (e) {
      throw _handleError(e); // DioException 由 _handleError 处理
    } catch (e) { // 捕获上面抛出的字符串错误
      rethrow; // 重新抛出，以便调用者可以捕获
    }
  }

  // --- 新增：获取推荐商品列表 ---
  Future<Map<String, dynamic>> getRecommendedProducts() async {
    // 尝试获取 token
    final token = await UserService.getToken();
    if (token == null) {
      // 推荐接口需要 token
      throw '用户未登录，无法获取推荐商品';
      // 或者 return {'code': 'AUTH_ERROR', 'info': '用户未登录'};
    }

    try {
      final response = await _dio.get(
        '/recommend/user/product', // 推荐商品 API 路径
        options: Options(
          headers: {
            'Authorization': token, // 传递 token
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Recommended Products Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        // API 直接返回列表数据在 'data' 字段下，包装成统一格式以便页面处理
        return {
          'code': response.data['code'],
          'info': response.data['info'],
          'data': {
            // 确保 list 存在，如果 data 为 null 或不是 List 则返回空列表
            'list': response.data['data'] is List ? response.data['data'] : [],
          },
        };
      }
      throw response.data['info'] ?? '获取推荐商品失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // --- 新增：获取热门商品列表 ---
  Future<Map<String, dynamic>> getHotProducts() async {
    // 尝试获取 token，虽然此接口可能不需要，但保持一致性
    final token = await UserService.getToken();
    try {
      final response = await _dio.get(
        '/recommend/hot/products', // 热门商品 API 路径
        options: Options(
          headers: {
            'Authorization': token ?? '', // 传递 token 或空字符串
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Hot Products Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        // API 直接返回列表数据在 'data' 字段下，包装成统一格式以便页面处理
        return {
          'code': response.data['code'],
          'info': response.data['info'],
          'data': {
            // 确保 list 存在，如果 data 为 null 或不是 List 则返回空列表
            'list': response.data['data'] is List ? response.data['data'] : [],
          },
        };
      }
      throw response.data['info'] ?? '获取热门商品失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // --- 新增：发布帖子 ---
  Future<Map<String, dynamic>> publishPost({
    required String title,
    required String content,
    required List<String> images,
    required bool isPublic,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法发布帖子';
    }

    try {
      final response = await _dio.post(
        '/posts/publish', // 发布帖子的 API 路径
        data: {
          'title': title,
          'content': content,
          'images': images,
          'isPublic': isPublic ? 1 : 0, // 将 bool 转换为 1 或 0
        },
        options: Options(
          headers: {
            'Authorization': token, // 传递 token
            'Accept': 'application/json',
          },
        ),
      );

      print('Publish Post Response: ${response.data}');

      // 检查响应码和业务码
      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 如果发布失败，抛出后端返回的错误信息
      throw response.data['info'] ?? '发布帖子失败';
    } on DioException catch (e) {
      // 处理 Dio 异常
      throw _handleError(e);
    } catch (e) {
      print('Error publishing post: $e');
      throw '发布帖子时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：发布评论 ---
  Future<Map<String, dynamic>> publishComment({
    required int entityId,
    required String entityType,
    required String content,
    String? imageUrl,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法发布评论';
    }

    try {
      final response = await _dio.post(
        '/comments/publish',
        data: {
          'entityId': entityId,
          'entityType': entityType,
          'content': content,
          'imageUrl': imageUrl ?? '',
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Publish Comment Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '发布评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error publishing comment: $e');
      throw '发布评论时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：回复评论 ---
  Future<Map<String, dynamic>> publishReply({
    required int replyCommentId,
    required dynamic parentId,
    required String content,
    String? imageUrl,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法回复评论';
    }

    try {
      final response = await _dio.post(
        '/comments/publish/reply',
        data: {
          'replyCommentId': replyCommentId,
          'parentId': parentId,
          'content': content,
          'imageUrl': imageUrl ?? '',
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Publish Reply Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '回复评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error publishing reply: $e');
      throw '回复评论时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：删除帖子 ---
  Future<Map<String, dynamic>> deletePost(String postId) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    if (token == null) {
      // 如果没有 token，则无法删除，可以抛出错误或返回特定 Map
      throw '用户未登录，无法删除帖子';
      // 或者 return {'code': 'AUTH_ERROR', 'info': '用户未登录'};
    }

    try {
      final response = await _dio.post(
        '/posts/delete/$postId', // 删除帖子的 API 路径
        options: Options(
          headers: {
            'Authorization': token, // 传递 token
            'Accept': 'application/json',
          },
        ),
      );

      print('Delete Post Response: ${response.data}');

      // 检查响应码和业务码
      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      // 如果删除失败，抛出后端返回的错误信息
      throw response.data['info'] ?? '删除帖子失败';
    } on DioException catch (e) {
      // 处理 Dio 异常
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // --- 新增：点赞评论 ---
  Future<Map<String, dynamic>> likeComment({
    required int commentId,
    int? parentId,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法点赞评论';
    }

    try {
      final response = await _dio.post(
        '/comments/like',
        data: {
          'commentId': commentId,
          'parentId': parentId,
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Like Comment Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '点赞评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error liking comment: $e');
      throw '点赞评论时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：取消点赞评论 ---
  Future<Map<String, dynamic>> unlikeComment({
    required int commentId,
    int? parentId,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法取消点赞评论';
    }

    try {
      final response = await _dio.post(
        '/comments/unlike',
        data: {
          'commentId': commentId,
          'parentId': parentId,
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Unlike Comment Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '取消点赞评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error unliking comment: $e');
      throw '取消点赞评论时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：获取商品分类树 ---
  Future<List<CategoryNode>> getCategoryTree() async {
    try {
      final response = await _dio.get(
        '/sale/category/tree', // 分类树 API 路径
        options: Options(
          headers: {
            // 根据 API 文档，此接口可能不需要 token，如果需要则添加
            // 'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Category Tree Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        final List<dynamic> dataList = response.data['data'] as List? ?? [];
        // 将 JSON 列表映射到 CategoryNode 列表
        return dataList.map((json) => CategoryNode.fromJson(json)).toList();
      }
      throw response.data['info'] ?? '获取分类失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      // 添加通用 catch 处理可能的映射错误
      print('Error parsing category tree: $e');
      throw '解析分类数据失败';
    }
  }
  // --- 新增结束 ---

  // --- 新增：根据分类 ID 获取商品列表（分页） ---
  Future<Map<String, dynamic>> getProductsByCategory({
    required int categoryId,
    int? lastId, // 可选的 lastId
    int size = 20, // 默认每页大小
  }) async {
    try {
      // 构建查询参数
      final Map<String, dynamic> queryParameters = {'size': size};
      if (lastId != null) {
        queryParameters['lastId'] = lastId;
      }

      final response = await _dio.get(
        '/sale/by-category/$categoryId', // 分类商品 API 路径
        queryParameters: queryParameters, // 传递查询参数
        options: Options(
          headers: {
            // 根据 API 文档，此接口可能不需要 token，如果需要则添加
            // 'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print(
        'Get Products By Category ($categoryId) Response: ${response.data}',
      );

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        // API 直接返回分页结构在 'data' 字段下
        return response.data; // 直接返回整个响应，页面会处理 'data' 里的 'list'
      }
      throw response.data['info'] ?? '获取分类商品失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error fetching products by category: $e');
      throw '获取分类商品数据失败';
    }
  }
  // --- 新增结束 ---

  // --- 新增：上传文件 ---
  Future<String> uploadFile(XFile file) async {
    final token = await UserService.getToken();
    String fileName = file.path.split('/').last;
    print('准备上传文件: $fileName, Path: ${file.path}');

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    try {
      // 注意：这里的 post 请求会使用上面 Dio 实例配置的超时时间
      final response = await _dio.post(
        '/file/upload',
        data: formData,
        options: Options(
          headers: {
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
        // onSendProgress: (int sent, int total) {
        //   if (total > 0) {
        //     double progress = sent / total * 100;
        //     print('上传进度: ${progress.toStringAsFixed(0)}%');
        //     // TODO: 将进度传递给 UI 层 (可选)
        //   }
        // },
      );

      print('文件上传响应: ${response.statusCode}, Data: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        if (response.data['data'] is String) {
          print('文件上传成功，URL: ${response.data['data']}');
          return response.data['data'];
        } else {
          print('文件上传失败: 返回的 data 字段不是 String');
          throw '上传成功，但返回的 URL 格式不正确';
        }
      }
      print('文件上传失败: Code: ${response.data['code']}, Info: ${response.data['info']}');
      throw response.data['info'] ?? '上传文件失败';
    } on DioException catch (e) {
      print('DioException 上传文件时: ${e.message}');
      print('DioException Response: ${e.response?.data}');
      // 现在 _handleError 会处理新的超时错误信息（如果发生）
      throw _handleError(e);
    } catch (e, stackTrace) {
      print('未知错误上传文件时: $e');
      print('Stack trace: $stackTrace');
      throw '上传文件时发生未知错误';
    }
  }
  // --- 上传文件结束 ---

    // 获取帖子详情页的推荐帖子
  // 获取帖子相关商品推荐
  Future<Map<String, dynamic>> getProductRecommendByPost({
    required String postsId,
  }) async {
    try {
      final response = await _dio.get(
        '/tagging/products/posts/$postsId',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw response.data['info'] ?? '获取商品推荐失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 原有的帖子推荐方法
  Future<Map<String, dynamic>> getRecommendContentForPost({
    required String postAuthorId,
    int topN = 6,
  }) async {
    // 尝试获取 token
    final token = await UserService.getToken();

    try {
      final response = await _dio.get(
        '/recommend/content',
        queryParameters: {'postAuthorId': postAuthorId, 'topN': topN},
        options: Options(
          headers: {
            'Authorization': token ?? '', // 如果 token 为 null，则传递空字符串
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw '获取推荐帖子失败：${response.data['info'] ?? '未知错误'}';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> updateUserInfo({
    String? username,
    String? avatarUrl,
    String? bio,
    int? age,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法更新信息';
    }

    try {
      final response = await _dio.post(
        '/user/update/info',
        data: {
          'username': username,
          'avatarUrl': avatarUrl,
          'bio': bio,
          'age': age,
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return true;
      }
      throw response.data['info'] ?? '更新信息失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取一级评论列表
  Future<Map<String, dynamic>> getComments({
    required String entityType,
    required String entityId,
    int page = 1,
    int size = 10,
  }) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    
    try {
      final response = await _dio.get(
        '/comments/$entityType/$entityId/list',
        queryParameters: {
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Comments Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取二级评论列表
  Future<Map<String, dynamic>> getReplyComments({
    required String parentId,
    String? lastId,
  }) async {
    // 尝试获取 token
    final token = await UserService.getToken();
    
    try {
      final queryParams = <String, dynamic>{};
      if (lastId != null) {
        queryParams['lastId'] = lastId;
      }
      
      final response = await _dio.get(
        '/comments/$parentId/reply/list',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': token ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      print('Get Reply Comments Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取回复评论失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 添加商品浏览记录的方法
  Future<void> createViewOrder(int productId) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法记录浏览';
    }

    try {
      final response = await _dio.post(
        '/sale/create_view_order',
        queryParameters: {'productId': productId},
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 || response.data['code'] != 'SUCCESS_0000') {
        throw response.data['info'] ?? '记录浏览失败';
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 新增方法：获取商品信息
  Future<Map<String, dynamic>> getProductInfo(int productId) async {
    try {
      final response = await _dio.get('/sale/product_info/$productId');
      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取商品信息失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- 新增：获取商品列表（搜索） - 分页 ---
  Future<Map<String, dynamic>> queryProductList({
    required String productName,
    required int lastId,
    required int pageSize,
  }) async {
    try {
      final response = await _dio.post(
        '/sale/query_product_list',
        data: {
          'productName': productName,
          'lastId': lastId,
          'pageSize': pageSize,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      print('Query Product List Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '搜索商品失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- 新增：获取商品详情 ---
  Future<Map<String, dynamic>> getProductDetail(int productId) async {
    try {
      final response = await _dio.get('/sale/product_info/$productId');
      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      print('Get Product Detail Response: ${response.data}');
      throw response.data['info'] ?? '获取商品信息失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- 新增：加入购物车 ---
  Future<Map<String, dynamic>> addToCart({
    required int productId,
    required int productNum,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法加入购物车';
    }

    try {
      final response = await _dio.post(
        '/sale/add_cart',
        data: {'productId': productId, 'productNum': productNum},
        options: Options(
          headers: {'Authorization': token, 'Accept': 'application/json'},
        ),
      );

      print('Add to Cart Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        return response
            .data; // 返回 {"code": "SUCCESS_0000", "info": "成功", "data": "添加成功"}
      }
      throw response.data['info'] ?? '加入购物车失败';
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error adding to cart: $e');
      throw '加入购物车时发生未知错误';
    }
  }

  // --- 新增：获取购物车列表 ---
  Future<Map<String, dynamic>> getCartList() async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法获取购物车列表';
    }

    try {
      final response = await _dio.get(
        '/sale/cart_list',
        options: Options(
          headers: {'Authorization': token, 'Accept': 'application/json'},
        ),
      );

      print('Get Cart List Response: ${response.data}');

      if (response.statusCode == 200 &&
          response.data['code'] == 'SUCCESS_0000') {
        // 确保 data 和 data['list'] 存在且是 List 类型
        if (response.data['data'] != null && response.data['data']['list'] is List) {
           return response.data;
        } else {
          // 如果 data 或 list 不存在或类型不对，返回一个空的列表结构
          return {
            'code': 'SUCCESS_0000',
            'info': '成功',
            'data': {'list': []} // 返回空列表
          };
        }
      }
      // 如果请求失败或业务码错误，也返回空列表结构或抛出错误
       return {
            'code': response.data['code'] ?? 'UNKNOWN_ERROR',
            'info': response.data['info'] ?? '获取购物车列表失败',
            'data': {'list': []} // 返回空列表
          };
      // 或者根据需要抛出错误: throw response.data['info'] ?? '获取购物车列表失败';
    } on DioException catch (e) {
       print('Error fetching cart list: ${_handleError(e)}');
       // 网络或服务器错误时返回空列表结构
       return {
            'code': 'NETWORK_ERROR', // 自定义错误码
            'info': _handleError(e),
            'data': {'list': []} // 返回空列表
          };
      // 或者抛出错误: throw _handleError(e);
    } catch (e) {
      print('Unknown error fetching cart list: $e');
       // 其他未知错误时返回空列表结构
       return {
            'code': 'UNKNOWN_ERROR',
            'info': '获取购物车列表时发生未知错误',
            'data': {'list': []} // 返回空列表
          };
      // 或者抛出错误: throw '获取购物车列表时发生未知错误';
    }
  }
  // --- 新增结束 ---

  // --- 新增：删除购物车商品 ---
  Future<Map<String, dynamic>> deleteCartItem(String cartId) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录';
    }

    try {
      final response = await _dio.post(
        '/sale/delete_cart/$cartId', // 使用 POST 方法和路径参数
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Delete Cart Item Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '删除购物车商品失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // --- 新增：结算购物车创建支付订单 ---
  Future<Map<String, dynamic>> createPayOrder(int productId) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录';
    }

    try {
      final response = await _dio.post(
        '/sale/create_pay_order', // 使用 POST 方法
        queryParameters: {'productId': productId}, // 将 productId 作为查询参数
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      print('Create Pay Order Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '创建支付订单失败';
    } on DioException catch (e) {
      // 可以根据需要处理特定错误，例如库存不足等
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // 获取订单列表
  Future<Map<String, dynamic>> getOrders({
    int type = -1,
    int page = 1,
    int size = 10,
  }) async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录';
    }

    try {
      final response = await _dio.get(
        '/sale/order_list/$type',
        queryParameters: {
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw response.data['info'] ?? '获取订单失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- 新增：获取评论列表 ---
  Future<Map<String, dynamic>> getCommentList({
    required String entityType,
    required int entityId,
    int? page,
    int? size,
  }) async {
    try {
      final token = await UserService.getToken();
      final options = token != null
          ? Options(headers: {'Authorization': token})
          : Options();

      final response = await _dio.get(
        '/comments/$entityType/$entityId/list',
        queryParameters: {
          if (page != null) 'page': page,
          if (size != null) 'size': size,
        },
        options: options,
      );

      print('Get Comment List Response: ${response.data}');

      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        return response.data;
      }
      throw response.data['info'] ?? '获取评论列表失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  // --- 新增结束 ---

  // 获取好友列表
  Future<List<Map<String, dynamic>>> getFriends() async {
    final token = await UserService.getToken();
    if (token == null) {
      throw '用户未登录，无法获取好友列表';
    }
    try {
      final response = await _dio.get(
        '/user/friends',
        options: Options(
          headers: {
            'Authorization': token,
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['code'] == 'SUCCESS_0000') {
        final data = response.data['data'];
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          return [];
        }
      }
      throw response.data['info'] ?? '获取好友列表失败';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}

