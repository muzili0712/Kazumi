import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/pages/error/http_error.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';

class PopularPage extends StatefulWidget {
  const PopularPage({super.key});

  @override
  State<PopularPage> createState() => _PopularPageState();
}

class _PopularPageState extends State<PopularPage>
    with AutomaticKeepAliveClientMixin {
  DateTime? _lastPressedAt;
  bool timeout = false;
  bool searchLoading = false;
  bool showTagFilter = true;
  bool showSearchBar = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final TextEditingController keywordController = TextEditingController();
  final PopularController popularController = Modular.get<PopularController>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    timeout = false;
    scrollController.addListener(() {
      popularController.scrollOffset = scrollController.offset;
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          popularController.isLoadingMore == false &&
          popularController.searchKeyword == '') {
        KazumiLogger().log(Level.info, 'Popular 正在加载更多');
        popularController.queryBangumiListFeed(type: 'onload');
      }
    });
    if (popularController.bangumiList.isEmpty) {
      // KazumiLogger().log(Level.info, 'Popular缓存列表为空, 尝试重加载');
      Timer(const Duration(seconds: 3), () {
        timeout = true;
      });
      popularController.queryBangumiListFeed();
    }
  }

  @override
  void dispose() {
    popularController.searchKeyword = '';
    _focusNode.dispose();
    scrollController.removeListener(() {});
    super.dispose();
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      SmartDialog.showToast("再按一次退出应用");
      return;
    }
    SystemNavigator.pop(); // 退出应用
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 暂时移除，某些情况下可能 crash
      // scrollController.jumpTo(popularController.scrollOffset);
    });
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await popularController.queryBangumiListFeed(
              tag: popularController.currentTag);
        },
        child: Scaffold(
            appBar: SysAppBar(
              leading: (Utils.isCompact())
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 10,
                        ),
                        ClipOval(
                          child: Image.asset(
                            'assets/images/logo/logo_android.png',
                          ),
                        ),
                      ],
                    )
                  : null,
              backgroundColor: Colors.transparent,
              title: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Container(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Visibility(
                          visible: showSearchBar,
                          child: TextFormField(
                            focusNode: _focusNode,
                            cursorColor: Theme.of(context).colorScheme.primary,
                            decoration: const InputDecoration(
                              alignLabelWithHint: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                            ),
                            style: TextStyle(
                                color:
                                    isLight ? Colors.black87 : Colors.white70),
                            onChanged: (_) {
                              scrollController.jumpTo(0.0);
                            },
                            controller: keywordController,
                            onFieldSubmitted: (t) async {
                              setState(() {
                                searchLoading = true;
                                popularController.currentTag = '';
                              });
                              if (t != '') {
                                popularController.searchKeyword = t;
                                await popularController.queryBangumi(
                                    popularController.searchKeyword);
                              } else {
                                popularController.searchKeyword = '';
                                await popularController.queryBangumiListFeed();
                              }
                              setState(() {
                                searchLoading = false;
                              });
                            },
                          ),
                        ),
                      ),
                      IconButton(
                          onPressed: () async {
                            if (!showSearchBar) {
                              setState(() {
                                showSearchBar = true;
                              });
                              _focusNode.requestFocus();
                            } else {
                              if (keywordController.text == '') {
                                _focusNode.unfocus();
                                setState(() {
                                  showSearchBar = false;
                                  searchLoading = true;
                                  popularController.currentTag = '';
                                });
                                popularController.searchKeyword == '';
                                await popularController.queryBangumiListFeed();
                                setState(() {
                                  searchLoading = false;
                                });
                              } else {
                                keywordController.text = '';
                                popularController.searchKeyword = '';
                                _focusNode.requestFocus();
                              }
                            }
                          },
                          icon: showSearchBar
                              ? const Icon(Icons.close)
                              : const Icon(Icons.search))
                    ],
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                SizedBox(
                  height: showTagFilter ? 50 : 0,
                  child: tagFilter(),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 0, bottom: 10, left: 0),
                          child: searchLoading
                              ? const LinearProgressIndicator()
                              : Container(),
                        ),
                      ),
                      SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              StyleString.safeSpace,
                              0,
                              StyleString.safeSpace,
                              0),
                          sliver: Observer(builder: (context) {
                            if (popularController.bangumiList.isEmpty &&
                                timeout == true) {
                              return HttpError(
                                errMsg: '什么都没有找到 (´;ω;`)',
                                fn: () {
                                  popularController.queryBangumiListFeed();
                                },
                              );
                            }
                            if (popularController.bangumiList.isEmpty &&
                                timeout == false) {
                              return SliverToBoxAdapter(
                                child: SizedBox(
                                    height:
                                        (MediaQuery.of(context).size.height /
                                            2),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(),
                                      ],
                                    )),
                              );
                            }
                            return contentGrid(popularController.bangumiList);
                          })),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                scrollController.jumpTo(0.0);
                popularController.scrollOffset = 0.0;
              },
              child: const Icon(Icons.arrow_upward),
            )
            // backgroundColor: themedata.colorScheme.primaryContainer,
            ),
      ),
    );
  }

  Widget contentGrid(bangumiList) {
    int crossCount = !Utils.isCompact() ? 6 : 3;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // 行间距
        mainAxisSpacing: StyleString.cardSpace - 2,
        // 列间距
        crossAxisSpacing: StyleString.cardSpace,
        // 列数
        crossAxisCount: crossCount,
        mainAxisExtent: MediaQuery.of(context).size.width / crossCount / 0.65 +
            MediaQuery.textScalerOf(context).scale(32.0),
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return bangumiList!.isNotEmpty
              ? BangumiCardV(bangumiItem: bangumiList[index])
              : null;
        },
        childCount: bangumiList!.isNotEmpty ? bangumiList!.length : 10,
      ),
    );
  }

  Widget tagFilter() {
    List<String> tags = [
      '日常',
      '原创',
      '校园',
      '搞笑',
      '奇幻',
      '百合',
      '异世界',
      '恋爱',
      '悬疑',
      '热血',
      '后宫',
      '机战'
    ];
    return Row(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final filter = tags[index];
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                child: filter == popularController.currentTag
                    ? FilledButton(
                        child: Text(filter),
                        onPressed: () async {
                          setState(() {
                            popularController.currentTag = '';
                            searchLoading = true;
                          });
                          await popularController.queryBangumiListFeed(
                            tag: popularController.currentTag,
                          );
                          setState(() {
                            searchLoading = false;
                          });
                        },
                      )
                    : FilledButton.tonal(
                        child: Text(filter),
                        onPressed: () async {
                          _focusNode.unfocus();
                          setState(() {
                            popularController.currentTag = filter;
                            keywordController.text = '';
                            showSearchBar = false;
                            searchLoading = true;
                          });
                          await popularController.queryBangumiListFeed(
                            tag: popularController.currentTag,
                          );
                          setState(() {
                            searchLoading = false;
                          });
                        },
                      ),
              );
            },
          ),
        ),
        Tooltip(
          message: '重设列表',
          child: IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () async {
              if (popularController.currentTag != '') {
                setState(() {
                  popularController.currentTag = '';
                  searchLoading = true;
                });
                await popularController.queryBangumiListFeed(
                  tag: popularController.currentTag,
                );
                setState(() {
                  searchLoading = false;
                });
              }
            },
          ),
        )
      ],
    );
  }
}
