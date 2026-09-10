import 'package:flutter/material.dart';

import 'screens/chat/chat_list_screen.dart';

void main() {
  runApp(const RentCollectionApp());
}

class RentCollectionApp extends StatelessWidget {
  const RentCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF2E7D32);
    return MaterialApp(
      title: 'Room & Tenant Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
      ),
      home: const ChatListScreen(),
    );
  }
}
