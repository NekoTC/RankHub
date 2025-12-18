import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/account_controller.dart';
import '../data/platforms_data.dart';
import '../widgets/queue_status_card.dart';
import './nearcade.dart';
class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = Get.find<AccountController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('工具箱'),
        titleSpacing: 24,
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // 排队状态卡片 - 默认展示
          const QueueStatusCard(),
          // Nearcard 入口（对所有用户展示）
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ListTile(
                leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.map_outlined, color: colorScheme.primary),
                ),
                title: const Text('nearcade'),
                subtitle: const Text('音游街机地图'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const NearcardPage()),
              ),
            ),
          // 平台自定义功能列表
          Obx(() {
            final currentAccount = controller.currentAccount;
            if (currentAccount == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.construction_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '未绑定账号',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '绑定账号后可使用平台专属功能',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            // 获取平台实例
            final platformRegistry = PlatformRegistry();
            final platform = platformRegistry.getPlatformByType(
              currentAccount.platform,
            );

            if (platform == null) {
              return const SizedBox.shrink();
            }

            // 获取自定义功能列表
            final features = platform.getCustomFeatures(
              context,
              currentAccount,
            );
            if (features.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无可用功能',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '该平台暂未提供额外功能',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < features.length; i++) ...[
                    features[i].buildWidget(context),
                    if (i < features.length - 1)
                      Divider(
                        height: 1,
                        indent: 72,
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
