import 'package:flutter/material.dart';

class ExportImage extends StatefulWidget {
  const ExportImage({super.key});

  @override
  State<ExportImage> createState() => _ExportImageState();
}

class _ExportImageState extends State<ExportImage> {


  @override
  void initState() {
    super.initState();

  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('交付导出'),
      ),
      
    );
  }



}