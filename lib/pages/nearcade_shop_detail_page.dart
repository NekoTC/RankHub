import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'nearcade.dart';

class NearcardShopDetailPage extends StatefulWidget {
  final String source;
  final int id;

  const NearcardShopDetailPage({
    super.key,
    required this.source,
    required this.id,
  });

  @override
  State<NearcardShopDetailPage> createState() => _NearcardShopDetailPageState();
}

class _NearcardShopDetailPageState extends State<NearcardShopDetailPage> {
  late Future<Shop> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchDetail();
  }

  Future<Shop> _fetchDetail() async {
    final resp = await http.get(
      Uri.parse(
        'https://nearcade.phizone.cn/api/shops/${widget.source}/${widget.id}',
      ),
    );
    if (resp.statusCode != 200) {
      throw Exception('请求失败：${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final shopJson = data['shop'] as Map<String, dynamic>;
    return Shop.fromJson(shopJson);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店铺详情')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<Shop>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
            final shop = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  shop.name ?? '未命名机厅',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (shop.comment != null && shop.comment!.trim().isNotEmpty)
                  Text(
                    shop.comment!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                if (shop.address != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        [
                          if (shop.address!.general.isNotEmpty)
                            shop.address!.general.join(' / '),
                          if (shop.address!.detailed != null &&
                              shop.address!.detailed!.isNotEmpty)
                            shop.address!.detailed!,
                        ].where((e) => e.isNotEmpty).join(' · '),
                      ),
                      subtitle: Text(
                        '数据源: ${shop.source ?? '-'} · ID: ${shop.id ?? shop.mongoId ?? '-'}',
                      ),
                    ),
                  ),
                if (shop.location != null &&
                    shop.location!.coordinates.length >= 2)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(
                        '坐标: (${shop.location!.coordinates[1]}, ${shop.location!.coordinates[0]})',
                      ),
                    ),
                  ),
                if (shop.games.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '机台列表',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...shop.games.map((g) {
                    final title = (g.name ?? '未命名机台') +
                        (g.version != null && g.version!.isNotEmpty
                            ? ' (${g.version})'
                            : '');
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.videogame_asset),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (g.comment != null &&
                                g.comment!.trim().isNotEmpty)
                              Text(g.comment!),
                            Text('数量: ${g.quantity ?? '-'}  价格: ${g.cost ?? '-'}'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}