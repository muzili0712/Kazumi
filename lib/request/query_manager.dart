import 'dart:async';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/plugins/plugins_controller.dart'; 

class QueryManager {
  final InfoController infoController = Modular.get<InfoController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late StreamController _controller;
  bool _isCancelled = false;

  Future<void> querySource(String keyword) async {
    _controller = StreamController();
    infoController.pluginSearchResponseList.clear();

    for (Plugin plugin in pluginsController.pluginList) {
      infoController.pluginSearchStatus[plugin.name] = 'pending';
    }

    for (Plugin plugin in pluginsController.pluginList) {
      if (_isCancelled) return; 

      plugin.queryBangumi(keyword).then((result) {
        if (_isCancelled) return; 

        infoController.pluginSearchStatus[plugin.name] = 'success';
        _controller.add(result);
      }).catchError((error) {
        if (_isCancelled) return; 

        infoController.pluginSearchStatus[plugin.name] = 'error';
      });
    }

    await for (var result in _controller.stream) {
      if (_isCancelled) break; 

      infoController.pluginSearchResponseList.add(result);
    }
  }

  void cancel() {
    _isCancelled = true;
    _controller.close();
  }
}
