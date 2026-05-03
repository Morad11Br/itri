import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kGold = Color(0xFFC9A227);
const Color kGoldLight = Color(0xFFE8C84A);
const Color kGoldPale = Color(0xFFFDF8EC);
const Color kOud = Color(0xFF3D2314);
const Color kRose = Color(0xFFD4A5A5);
const Color kCream = Color(0xFFFAF6F0);
const Color kEspresso = Color(0xFF2C1810);
const Color kWarmGray = Color(0xFF6B5B4F);
const Color kSand = Color(0xFFA8A29E);
const Color kSuccess = Color(0xFF059669);
const Color kAmber = Color(0xFFD97706);

const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x142C1810), blurRadius: 12, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x0D2C1810), blurRadius: 3, offset: Offset(0, 1)),
];

const List<BoxShadow> kGoldShadow = [
  BoxShadow(color: Color(0x2EC9A227), blurRadius: 16, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x1EC9A227), blurRadius: 4, offset: Offset(0, 1)),
];

TextStyle arabicStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = kEspresso,
  double? height,
}) => GoogleFonts.ibmPlexSansArabic(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  height: height,
);

TextStyle serifStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = kWarmGray,
  bool italic = false,
}) => GoogleFonts.ibmPlexSansArabic(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
);

ThemeData buildTheme() {
  final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme();

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: kGold),
    useMaterial3: true,
    scaffoldBackgroundColor: kCream,
    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
    textTheme: textTheme,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kOud,
      contentTextStyle: arabicStyle(fontSize: 14, color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
