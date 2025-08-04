import 'package:flutter/material.dart';

class QualityInspectionList extends StatefulWidget{
  @override
  State<StatefulWidget> createState() =>QualityInspectionListState();
}

class QualityInspectionListState extends State<QualityInspectionList>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('质检列表'),),
    );
  }
}