import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:hive/hive.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  final HistoryController historyController = Modular.get<HistoryController>();
  Box setting = GStorage.setting;

  /// show delete button
  bool showDelete = false;

  @override
  void initState() {
    super.initState();
    historyController.init();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
  }

  void showHistoryClearDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('记录管理'),
          content: const Text('确认要清除所有历史记录吗?'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                try {
                  historyController.clearAll();
                } catch (_) {}
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void showWebDavUploadDialog() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      KazumiDialog.showToast(message: 'WebDAV未启用或未开启历史记录同步');
      return;
    }

    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('上传确认'),
          content: const Text('确认要将本地历史记录上传到WebDAV吗？'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                KazumiDialog.dismiss();
                KazumiDialog.showLoading(msg: '上传历史记录到WebDAV...');
                try {
                  await historyController.uploadHistoryToWebDav();
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '上传历史记录到WebDAV成功');
                } catch (e) {
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '上传历史记录失败: ${e.toString()}');
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void showWebDavDownloadDialog() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      KazumiDialog.showToast(message: 'WebDAV未启用或未开启历史记录同步');
      return;
    }

    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('下载确认'),
          content: const Text('确认要从WebDAV下载历史记录吗？这将与本地记录合并。'),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                KazumiDialog.dismiss();
                KazumiDialog.showLoading(msg: '从WebDAV下载历史记录...');
                try {
                  await historyController.downloadHistoryFromWebDav();
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '从WebDAV下载历史记录成功');
                } catch (e) {
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '下载历史记录失败: ${e.toString()}');
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void showWebDavSyncDialog() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      KazumiDialog.showToast(message: 'WebDAV未启用或未开启历史记录同步');
      return;
    }

    KazumiDialog.showLoading(msg: 'WebDAV同步中...');
    try {
      await historyController.manualSyncWebDav();
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: 'WebDAV同步成功');
    } catch (e) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: 'WebDAV同步失败: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return Observer(builder: (context) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          onBackPressed(context);
        },
        child: Scaffold(
          appBar: SysAppBar(
            title: const Text('历史记录'),
            actions: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      showDelete = !showDelete;
                    });
                  },
                  icon: showDelete
                      ? const Icon(Icons.edit_outlined)
                      : const Icon(Icons.edit))
            ],
          ),
          body: SafeArea(bottom: false, child: renderBody),
          floatingActionButton: buildFloatingActionButtons(),
        ),
      );
    });
  }

  Widget buildFloatingActionButtons() {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    bool showWebDavButtons = webDavEnable && webDavEnableHistory;

    List<Widget> buttons = [];

    if (showWebDavButtons) {
      buttons.addAll([
        FloatingActionButton(
          heroTag: "upload",
          onPressed: () {
            showWebDavUploadDialog();
          },
          tooltip: '上传到WebDAV',
          child: const Icon(Icons.upload),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: "download",
          onPressed: () {
            showWebDavDownloadDialog();
          },
          tooltip: '从WebDAV下载',
          child: const Icon(Icons.download),
        ),
        const SizedBox(height: 8),
      ]);
    }

    buttons.add(
      FloatingActionButton(
        heroTag: "clear",
        onPressed: () {
          showHistoryClearDialog();
        },
        tooltip: '清空历史记录',
        child: const Icon(Icons.clear_all),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }

  Widget get renderBody {
    if (historyController.histories.isNotEmpty) {
      return contentGrid;
    } else {
      return const Center(
        child: Text('没有找到历史记录 (´;ω;`)'),
      );
    }
  }

  Widget get contentGrid {
    int crossCount = 1;
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (MediaQuery.sizeOf(context).width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }
    double cardHeight = 120;

    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            mainAxisSpacing: StyleString.cardSpace - 2,
            crossAxisSpacing: StyleString.cardSpace,
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight + 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return historyController.histories.isNotEmpty
                  ? BangumiHistoryCardV(
                      showDelete: showDelete,
                      cardHeight: cardHeight,
                      historyItem: historyController.histories[index])
                  : null;
            },
            childCount: historyController.histories.isNotEmpty
                ? historyController.histories.length
                : 10,
          ),
        ),
      ],
    );
  }
}
