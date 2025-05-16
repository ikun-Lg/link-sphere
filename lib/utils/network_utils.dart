import 'dart:io';
import 'package:dio/dio.dart';

class NetworkUtils {
  /// 处理API错误并返回用户友好的错误消息
  static String handleApiError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '连接服务器超时，请检查您的网络连接';
        case DioExceptionType.sendTimeout:
          return '发送请求超时，请稍后重试';
        case DioExceptionType.receiveTimeout:
          return '接收数据超时，请稍后重试';
        case DioExceptionType.badResponse:
          if (error.response?.statusCode == 500) {
            return '服务器内部错误 (500)：${error.response?.data?['info'] ?? '未知错误'}';
          } else if (error.response?.statusCode == 404) {
            return '请求的资源不存在 (404)';
          } else if (error.response?.statusCode == 401) {
            return '未授权，请重新登录 (401)';
          } else if (error.response?.statusCode == 400) {
            return '请求参数错误 (400)：${error.response?.data?['info'] ?? ''}';
          }
          return '服务器返回错误：${error.response?.statusCode} - ${error.response?.data?['info'] ?? '未知错误'}';
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return '网络连接失败，请检查您的网络设置';
          }
          return '未知错误：${error.message}';
        default:
          return '网络请求失败：${error.message}';
      }
    }
    
    return error?.toString() ?? '发生未知错误';
  }
  
  /// 显示服务器内部错误的详细信息
  static String formatServerError(dynamic errorData) {
    if (errorData == null) return '无详细信息';
    
    try {
      if (errorData is Map) {
        return 'Error: ${errorData['info'] ?? ''}\nCode: ${errorData['code'] ?? ''}\nData: ${errorData['data'] ?? 'null'}';
      } else if (errorData is String) {
        return errorData;
      } else {
        return errorData.toString();
      }
    } catch (e) {
      return '解析错误详情失败: $e';
    }
  }
} 