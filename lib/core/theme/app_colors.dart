import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFAF5FF);
  static const plum = Color(0xFF911B44);
  static const deep = Color(0xFF3C1226);
  static const plumDeep = Color(0xFF7C012D);
  static const orange = Color(0xFFEC5914);
  static const orangeLt = Color(0xFFFFE7DB);
  static const ink = Color(0xFF2D1923);
  static const green = Color(0xFF006C4F);
  static const greenLt = Color(0xFFAFE4DC);
  static const mid = Color(0x802D1923);
  static const border = Color(0x1A911B44);

  static const grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [plum, orange],
  );
}
