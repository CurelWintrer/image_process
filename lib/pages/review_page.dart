import 'package:flutter/material.dart';

class ReviewPage extends StatefulWidget{
  @override
  State<StatefulWidget> createState()=>ReviewPageState();
}

class ReviewPageState extends State<ReviewPage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('质检页面'),),
    );
  }
}