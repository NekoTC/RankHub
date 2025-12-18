import 'dart:convert';
import 'package:techno_kitchen_dart/src/request_adapter.dart';
import 'package:techno_kitchen_dart/techno_kitchen_dart.dart';
import 'package:rank_hub/models/maimai/net_user.dart';
import 'package:rank_hub/models/maimai/net_score.dart';

/// Maimai DX NET API 服务
/// 使用 techno_kitchen_dart 与NET查分器通信
class MaimaiNetApiService {
  static final MaimaiNetApiService _instance = MaimaiNetApiService._internal();
  factory MaimaiNetApiService() => _instance;
  static MaimaiNetApiService get instance => _instance;

  MaimaiNetApiService._internal() {
    _requestAdapter = RequestAdapter(
      aesKey: String.fromEnvironment(
        'MAIMAI_NET_API_AES_KEY',
        defaultValue: 'SBGA',
      ),
      aesIv: String.fromEnvironment(
        'MAIMAI_NET_API_AES_IV',
        defaultValue: 'SBGA',
      ),
      obfuscateParam: String.fromEnvironment(
        'MAIMAI_NET_API_OBFUSCATE_PARAM',
        defaultValue: 'SBGA',
      ),
      keychipID: String.fromEnvironment(
        'MAIMAI_NET_API_KEYCHIP_ID',
        defaultValue: 'SBGA',
      ),
      salt: String.fromEnvironment('MAIMAI_NET_API_SALT', defaultValue: 'SBGA'),
      openGameID: String.fromEnvironment(
        'MAIMAI_NET_API_OPEN_GAME_ID',
        defaultValue: 'SBGA',
      ),
      chimeEndpoint: String.fromEnvironment(
        'MAIMAI_NET_API_CHIME_ENDPOINT',
        defaultValue: 'SBGA',
      ),
      titleEndpoint: String.fromEnvironment(
        'MAIMAI_NET_API_TITLE_ENDPOINT',
        defaultValue: 'SBGA',
      ),
    );
    _technoKitchen = TechnoKitchen(_requestAdapter);
  }

  late final RequestAdapter _requestAdapter;
  late final TechnoKitchen _technoKitchen;

  TechnoKitchen get client => _technoKitchen;

  /// 扫描QR Code获取用户信息
  /// [qrCode] 二维码内容，格式: SGWCMAID<16-digit timestamp YYMMDDHHMMSS><64-character QR code>
  /// 返回包含 errorID, userID, key, timestamp 的响应
  Future<Map<String, dynamic>> scanQrCode(String qrCode) async {
    try {
      final result = await _technoKitchen.client.qrApi(qrCode);

      // 检查错误
      if (result['errorID'] != 0) {
        throw Exception('QR Code扫描失败: errorID = ${result['errorID']}');
      }

      return result;
    } catch (e) {
      throw Exception('扫描QR Code失败: $e');
    }
  }

  /// 获取用户预览信息
  /// [userId] 用户ID
  /// 返回用户基本信息，包括用户名、Rating等
  Future<NetUser> getUserPreview(int userId) async {
    try {
      final previewJson = await _technoKitchen.preview(userId);
      final previewData = jsonDecode(previewJson);

      return NetUser.fromPreview(previewData);
    } catch (e) {
      throw Exception('获取用户预览失败: $e');
    }
  }

  /// 获取用户详细数据
  /// [userId] 用户ID
  /// 返回用户完整数据，包括统计信息等
  Future<Map<String, dynamic>> getUserData(int userId) async {
    try {
      // 登录
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _technoKitchen.login(userId, timestamp);

      // 获取用户数据
      final userDataJson = await _technoKitchen.userdata(userId);
      final userDataResult = jsonDecode(userDataJson);

      // 登出
      await _technoKitchen.logout(userId, timestamp);

      return userDataResult;
    } catch (e) {
      throw Exception('获取用户数据失败: $e');
    }
  }

  /// 获取用户音乐成绩
  /// [userId] 用户ID
  /// [maxCount] 每次请求最大数量，默认2000
  /// [startIndex] 起始索引，默认0
  /// 返回成绩列表
  Future<NetScoreResponse> getUserMusic(
    int userId, {
    int maxCount = 2000,
    int startIndex = 0,
  }) async {
    try {
      final userMusicJson = await _technoKitchen.getUserMusic(
        userId,
        maxCount: maxCount,
        nextIndex: startIndex,
      );

      final userMusicData = jsonDecode(userMusicJson);
      return NetScoreResponse.fromJson(userMusicData);
    } catch (e) {
      throw Exception('获取用户音乐成绩失败: $e');
    }
  }

  /// 获取用户所有成绩（分页获取）
  /// [userId] 用户ID
  /// [onProgress] 进度回调 (current, total, description)
  /// 返回所有成绩列表
  Future<List<NetScore>> getAllUserScores(
    int userId, {
    Function(int current, int total, String description)? onProgress,
  }) async {
    final allScores = <NetScore>[];
    int nextIndex = 0;
    int totalLength = 0;

    do {
      onProgress?.call(
        allScores.length,
        totalLength > 0 ? totalLength : allScores.length + 1,
        '正在获取成绩数据... (${allScores.length}/${totalLength > 0 ? totalLength : '?'})',
      );

      final response = await getUserMusic(
        userId,
        maxCount: 2000,
        startIndex: nextIndex,
      );

      // 提取所有成绩
      for (final musicItem in response.userMusicList) {
        allScores.addAll(musicItem.userMusicDetailList);
      }

      nextIndex = response.nextIndex;

      // 更新总数估计
      if (totalLength == 0 && response.length > 0) {
        // 粗略估计总数
        totalLength =
            allScores.length +
            (response.nextIndex > 0 ? response.length * 10 : 0);
      }

      // 如果 nextIndex 大于等于总长度，说明已经获取完毕
      if (nextIndex >= response.length || response.length == 0) {
        break;
      }
    } while (nextIndex > 0);

    onProgress?.call(allScores.length, allScores.length, '成绩获取完成！');

    return allScores;
  }

  /// 从QR Code创建并保存NET用户
  /// [qrCode] 二维码内容
  /// 返回完整的用户信息
  Future<NetUser> createUserFromQrCode(String qrCode) async {
    // 1. 扫描QR Code
    final qrResult = await scanQrCode(qrCode);

    // 2. 创建基础用户信息
    final netUser = NetUser.fromQrApi(qrResult);

    // 3. 获取用户详细信息
    try {
      final preview = await getUserPreview(netUser.userId);
      netUser.updateFromPreview(preview.toJson());
    } catch (e) {
      print('获取用户预览失败，使用基本信息: $e');
    }

    return netUser;
  }

  /// 通过用户ID创建NET用户
  /// [userId] 用户ID
  Future<NetUser> createUserFromUserId(int userId) async {
    // 直接获取用户预览信息
    final netUser = await getUserPreview(userId);
    return netUser;
  }
}
