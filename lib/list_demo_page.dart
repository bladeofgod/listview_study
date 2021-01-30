import 'package:flutter/material.dart';

import 'cache_entity.dart';
import 'fake_data.dart';

class ListDemoPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ListDemoPageState();
  }
}

class ListDemoPageState extends State<ListDemoPage> {
  final List<CacheEntity> listData = List.generate(20, (index) {
    return CacheEntity(FakeData.imageList[index], " $index");
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Material(
      color: Colors.white,
      child: Container(
        width: size.width,
        height: size.height,
        child: ListView.builder(
            itemCount: listData.length,
            itemBuilder: (ctx, index) {
              return buildItem(listData[index], index);
            }),
      ),
    );
  }

  Widget buildItem(CacheEntity entity, int index) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: index % 2 == 0 ? Colors.greenAccent[400] : Colors.lightBlueAccent[400],
        margin: EdgeInsets.only(top: 28, left: 40, right: 40),
        padding: EdgeInsets.all(10),
        width: 670,
        height: 420,
        child: Column(
          children: <Widget>[
            Image.network(
              entity.img,
              width: 650,
              height: 300,
              // loadingBuilder: (ctx, child, event) {
              //   return Center(
              //     child: Text(
              //       '加载中',
              //       style: TextStyle(fontSize: 20, color: Colors.black),
              //     ),
              //   );
              // },
            ),
            Text(
              "${entity.title} -- 测试缓存数据",
              style: TextStyle(color: Colors.black, fontSize: 32),
            ),
          ],
        ),
      ),
    );
  }
}
