
import 'dart:ui';

import 'package:flutter/material.dart';

class ImageState {
  static String getStateText(int? state) {
    switch (state) {
      case 0:
        return '未检查';
      case 1:
        return '正在检查';
      case 2:
        return '正在审核';
      case 3:
        return '审核通过';
      case 4:
        return '废弃';
      default:
        return '未知状态';
    }
  }

  static Color getStateColor(int? state) {
    switch (state) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.red;
      case 4:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }


}