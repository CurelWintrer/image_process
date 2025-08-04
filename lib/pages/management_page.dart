import 'package:flutter/material.dart';

class ManagementPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ManagementPageState();
}

class ManagementPageState extends State<ManagementPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('管理')));
  }
}
