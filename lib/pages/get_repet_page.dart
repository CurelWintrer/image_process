import 'package:flutter/material.dart';

class GetRepetPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _GetImageRepetState();
}

class _GetImageRepetState extends State<GetRepetPage> {

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('标题重复')),
    );
  }
}
