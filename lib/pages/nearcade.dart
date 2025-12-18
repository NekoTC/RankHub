import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import 'nearcade_shop_detail_page.dart';

class NearcardPage extends StatefulWidget {
  const NearcardPage({super.key});

  @override
  State<NearcardPage> createState() => _NearcardPageState();
}

class _NearcardPageState extends State<NearcardPage> {
  Future<List<Shop>>? _future; // 允许为空，避免未初始化
  Position? _position;
  String? _locationError;
  bool _loadingLocation = true;

  // 半径（公里），默认为 5
  final TextEditingController _radiusController =
  TextEditingController(text: '5');
  int? _radiusKm = 5;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndLoad() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    Position? position;
    try {
      position = await _getCurrentPosition();
    } catch (e) {
      _locationError = e.toString();
    }

    setState(() {
      _position = position;
      _loadingLocation = false;
      _future = _fetchShops();
    });
  }

  Future<Position?> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('定位服务未开启');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('定位权限被拒绝');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝，请到系统设置开启');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<Shop>> _fetchShops() async {
    http.Response resp;
    if (_position != null) {
      final lat = _position!.latitude.toString();
      final lon = _position!.longitude.toString();
      final uri = Uri.https(
        'nearcade.phizone.cn',
        '/api/discover',
        {
          'longitude': lon,
          'latitude': lat,
          if (_radiusKm != null && _radiusKm! > 0) 'radius': '$_radiusKm',
        },
      );
      resp = await http.get(uri);
    } else {
      resp = await http.get(Uri.parse('https://nearcade.phizone.cn/api/shops'));
    }

    if (resp.statusCode != 200) {
      throw Exception('请求失败：${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final shops = (data['shops'] as List<dynamic>? ?? [])
        .map((e) => Shop.fromJson(e as Map<String, dynamic>))
        .toList();
    return shops;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchShops();
    });
  }

  void _applyRadiusAndReload() {
    final txt = _radiusController.text.trim();
    final parsed = int.tryParse(txt);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于 0 的整数半径（公里）')),
      );
      return;
    }
    setState(() {
      _radiusKm = parsed;
      _future = _fetchShops();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('nearcade'),
        actions: [
          IconButton(
            tooltip: '重新定位',
            icon: const Icon(Icons.my_location),
            onPressed: _initLocationAndLoad,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingLocation)
            const LinearProgressIndicator(minHeight: 2)
          else if (_locationError != null)
            Container(
              width: double.infinity,
              color: colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_off, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: _initLocationAndLoad,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),

          // 半径输入
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '搜索半径 (公里)',
                      hintText: '例如 5',
                    ),
                    onSubmitted: (_) => _applyRadiusAndReload(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applyRadiusAndReload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('应用'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _future == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<Shop>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                '加载失败：${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _reload,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  final shops = snapshot.data ?? [];
                  if (shops.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('暂无机厅数据')),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    itemCount: shops.length,
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (shop.source != null && shop.id != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        NearcardShopDetailPage(
                                          source: shop.source!,
                                          id: shop.id!,
                                        ),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        shop.name ?? '未命名机厅',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (shop.distance != null)
                                      Chip(
                                        label: Text(
                                          '${shop.distance!.toStringAsFixed(1)} km',
                                        ),
                                        backgroundColor: colorScheme
                                            .primaryContainer,
                                        labelStyle: TextStyle(
                                          color: colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                  ],
                                ),
                                if (shop.address != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      if (shop.address!.general.isNotEmpty)
                                        shop.address!.general.join(' / '),
                                      if (shop.address!.detailed != null &&
                                          shop.address!.detailed!
                                              .isNotEmpty)
                                        shop.address!.detailed!,
                                    ]
                                        .where((e) => e.isNotEmpty)
                                        .join(' · '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                if (shop.games.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: shop.games.map((g) {
                                      final title =
                                          (g.name ?? '未命名机台') +
                                              (g.version != null &&
                                                  g.version!
                                                      .isNotEmpty
                                                  ? ' (${g.version})'
                                                  : '');
                                      return Chip(
                                        label: Text(title),
                                        avatar: const Icon(
                                          Icons.videogame_asset,
                                          size: 16,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ID: ${shop.id ?? shop.mongoId ?? '-'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (shop.location != null &&
                                        shop.location!.coordinates
                                            .length >=
                                            2)
                                      Text(
                                        '(${shop.location!.coordinates[1]}, ${shop.location!.coordinates[0]})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Shop {
  final String? mongoId;
  final int? id;
  final String? name;
  final String? comment;
  final ShopAddress? address;
  final List<List<int>> openingHours;
  final List<GameInfo> games;
  final ShopLocation? location;
  final String? source;
  final double? distance; // km
  final int? totalAttendance;
  final CurrentReportedAttendance? currentReportedAttendance;

  Shop({
    this.mongoId,
    this.id,
    this.name,
    this.comment,
    this.address,
    this.openingHours = const [],
    this.games = const [],
    this.location,
    this.source,
    this.distance,
    this.totalAttendance,
    this.currentReportedAttendance,
  });

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
    mongoId: json['_id'] as String?,
    id: json['id'] as int?,
    name: json['name'] as String?,
    comment: json['comment'] as String?,
    address: json['address'] != null
        ? ShopAddress.fromJson(json['address'] as Map<String, dynamic>)
        : null,
    openingHours: (json['openingHours'] as List<dynamic>? ?? [])
        .map((e) => (e as List<dynamic>).map((v) => v as int).toList())
        .toList(),
    games: (json['games'] as List<dynamic>? ?? [])
        .map((e) => GameInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
    location: json['location'] != null
        ? ShopLocation.fromJson(json['location'] as Map<String, dynamic>)
        : null,
    source: json['source'] as String?,
    distance: (json['distance'] as num?)?.toDouble(),
    totalAttendance: json['totalAttendance'] as int?,
    currentReportedAttendance:
    json['currentReportedAttendance'] != null
        ? CurrentReportedAttendance.fromJson(
      json['currentReportedAttendance']
      as Map<String, dynamic>,
    )
        : null,
  );
}

class ShopAddress {
  final List<String> general;
  final String? detailed;

  ShopAddress({this.general = const [], this.detailed});

  factory ShopAddress.fromJson(Map<String, dynamic> json) => ShopAddress(
    general: (json['general'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    detailed: json['detailed'] as String?,
  );
}

class GameInfo {
  final int? gameId;
  final int? titleId;
  final String? name;
  final String? version;
  final String? comment;
  final int? quantity;
  final String? cost;
  final int? totalAttendance;

  GameInfo({
    this.gameId,
    this.titleId,
    this.name,
    this.version,
    this.comment,
    this.quantity,
    this.cost,
    this.totalAttendance,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) => GameInfo(
    gameId: json['gameId'] as int?,
    titleId: json['titleId'] as int?,
    name: json['name'] as String?,
    version: json['version'] as String?,
    comment: json['comment'] as String?,
    quantity: json['quantity'] as int?,
    cost: json['cost'] as String?,
    totalAttendance: json['totalAttendance'] as int?,
  );
}

class ShopLocation {
  final String? type;
  final List<double> coordinates;

  ShopLocation({this.type, this.coordinates = const []});

  factory ShopLocation.fromJson(Map<String, dynamic> json) => ShopLocation(
    type: json['type'] as String?,
    coordinates: (json['coordinates'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toDouble())
        .toList(),
  );
}

class CurrentReportedAttendance {
  final DateTime? reportedAt;
  final String? reportedBy;
  final Reporter? reporter;
  final String? comment;

  CurrentReportedAttendance({
    this.reportedAt,
    this.reportedBy,
    this.reporter,
    this.comment,
  });

  factory CurrentReportedAttendance.fromJson(Map<String, dynamic> json) =>
      CurrentReportedAttendance(
        reportedAt: json['reportedAt'] != null
            ? DateTime.tryParse(json['reportedAt'] as String)
            : null,
        reportedBy: json['reportedBy'] as String?,
        reporter: json['reporter'] != null
            ? Reporter.fromJson(json['reporter'] as Map<String, dynamic>)
            : null,
        comment: json['comment'] as String?,
      );
}

class Reporter {
  final String? id;
  final String? name;
  final String? email;
  final String? image;
  final String? displayName;

  Reporter({
    this.id,
    this.name,
    this.email,
    this.image,
    this.displayName,
  });

  factory Reporter.fromJson(Map<String, dynamic> json) => Reporter(
    id: json['id'] as String?,
    name: json['name'] as String?,
    email: json['email'] as String?,
    image: json['image'] as String?,
    displayName: json['displayName'] as String?,
  );
}