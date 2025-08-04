import 'package:flutter/material.dart';

class GetImageRepetPage extends StatefulWidget{
  @override
  State<StatefulWidget> createState() =>_GeImageRepetPageState();
}

class _GeImageRepetPageState extends State<GetImageRepetPage>{
  @override
  void initState(){
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片重复'),
      )
    );
  }
}
