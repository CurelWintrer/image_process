import 'package:flutter/material.dart';

class QualityInspectionDetailPage extends StatefulWidget{
  @override
  State<StatefulWidget> createState() =>QualityInspectionDetailPageState();
}

class QualityInspectionDetailPageState extends State<QualityInspectionDetailPage>{

  @override
  void initState(){
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(title: Text('质检详情'),),
    );
  }
}