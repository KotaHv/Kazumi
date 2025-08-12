import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

abstract class _HistoryController with Store {
  Box setting = GStorage.setting;
  var storedHistories = GStorage.histories;

  @observable
  ObservableList<History> histories = ObservableList<History>();

  void init() {
    // 在历史记录页面初始化时从WebDAV同步历史记录
    _syncWebDAVHistoryOnInit();
  }

  Future<void> _syncWebDAVHistoryOnInit() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (webDavEnable && webDavEnableHistory) {
      try {
        var webDav = WebDav();
        await webDav.downloadAndPatchHistory();
        KazumiLogger().log(Level.info, '历史记录页面：WebDAV同步成功');
        // 同步完成后重新加载本地历史记录
        _loadLocalHistories();
      } catch (e) {
        KazumiLogger().log(Level.warning, '历史记录页面：WebDAV同步失败 ${e.toString()}');
        // 即使同步失败也要加载本地历史记录
        _loadLocalHistories();
      }
    } else {
      // 未启用WebDAV时直接加载本地历史记录
      _loadLocalHistories();
    }
  }

  void _loadLocalHistories() {
    var temp = storedHistories.values.toList();
    temp.sort(
      (a, b) =>
          b.lastWatchTime.millisecondsSinceEpoch -
          a.lastWatchTime.millisecondsSinceEpoch,
    );
    histories.clear();
    histories.addAll(temp);
  }

  void updateHistory(
      int episode,
      int road,
      String adapterName,
      BangumiItem bangumiItem,
      Duration progress,
      String lastSrc,
      String lastWatchEpisodeName) {
    bool privateMode =
        setting.get(SettingBoxKey.privateMode, defaultValue: false);
    if (privateMode) {
      return;
    }
    var history =
        storedHistories.get(History.getKey(adapterName, bangumiItem)) ??
            History(bangumiItem, episode, adapterName, DateTime.now(), lastSrc,
                lastWatchEpisodeName);
    history.lastWatchEpisode = episode;
    history.lastWatchTime = DateTime.now();
    if (lastSrc != '') {
      history.lastSrc = lastSrc;
    }
    if (lastWatchEpisodeName != '') {
      history.lastWatchEpisodeName = lastWatchEpisodeName;
    }

    var prog = history.progresses[episode];
    if (prog == null) {
      history.progresses[episode] =
          Progress(episode, road, progress.inMilliseconds);
    } else {
      prog.progress = progress;
    }

    storedHistories.put(history.key, history);
    // 只更新本地显示列表，不触发WebDAV同步
    // WebDAV同步由播放器的定时器负责
    _loadLocalHistories();
  }

  Progress? lastWatching(BangumiItem bangumiItem, String adapterName) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[history.lastWatchEpisode];
  }

  Progress? findProgress(
      BangumiItem bangumiItem, String adapterName, int episode) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[episode];
  }

  void deleteHistory(History history) {
    // 删除本地记录
    storedHistories.delete(history.key);

    // 立即上传到WebDAV，确保删除操作同步到云端
    _uploadToWebDavAfterDelete();

    // 更新本地显示列表
    _loadLocalHistories();
  }

  /// 删除操作后立即上传到WebDAV
  void _uploadToWebDavAfterDelete() {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (webDavEnable && webDavEnableHistory) {
      // 异步上传，不阻塞UI
      Future.delayed(Duration.zero, () async {
        try {
          var webDav = WebDav();
          await webDav.updateHistory(); // 直接上传当前本地状态
          KazumiLogger().log(Level.info, '历史记录删除后WebDAV上传成功');
        } catch (e) {
          KazumiLogger()
              .log(Level.warning, '历史记录删除后WebDAV上传失败: ${e.toString()}');
        }
      });
    }
  }

  void clearProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    var history = storedHistories.get(History.getKey(adapterName, bangumiItem));
    if (history != null && history.progresses.containsKey(episode)) {
      history.progresses[episode]!.progress = Duration.zero;
      // 保存修改到本地
      storedHistories.put(history.key, history);

      // 立即上传到WebDAV
      _uploadToWebDavAfterDelete();

      // 更新本地显示列表
      _loadLocalHistories();
    }
  }

  void clearAll() {
    GStorage.histories.clear();
    histories.clear();
    // init();
  }

  Future<void> manualSyncWebDav() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      throw Exception('WebDAV未启用或未开启历史记录同步');
    }

    var webDav = WebDav();
    await webDav.downloadAndPatchHistory();
    KazumiLogger().log(Level.info, '手动WebDAV历史记录同步成功');

    // 同步完成后重新加载本地历史记录
    _loadLocalHistories();
  }

  Future<void> uploadHistoryToWebDav() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      throw Exception('WebDAV未启用或未开启历史记录同步');
    }

    var webDav = WebDav();
    await webDav.update('histories');
    KazumiLogger().log(Level.info, '手动上传历史记录到WebDAV成功');
  }

  Future<void> downloadHistoryFromWebDav() async {
    bool webDavEnable =
        setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    bool webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);

    if (!webDavEnable || !webDavEnableHistory) {
      throw Exception('WebDAV未启用或未开启历史记录同步');
    }

    var webDav = WebDav();
    await webDav.downloadAndPatchHistory();
    KazumiLogger().log(Level.info, '手动从WebDAV下载历史记录成功');

    // 下载完成后重新加载本地历史记录
    _loadLocalHistories();
  }
}
