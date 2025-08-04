import 'package:flutter/material.dart';

class AllImagePage extends StatefulWidget{
  @override
  State<StatefulWidget> createState() =>AllImagePageState();
}

class AllImagePageState extends State<AllImagePage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Image')),
    );
  }
}