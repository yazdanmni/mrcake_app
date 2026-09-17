import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_banner.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_header.dart';

class ProfileScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Stack(children: [ProfileHeader()]),
          ProfileBanner(
            onImageChanged: (File? image) {
              setState(() {
                
              });
            },
          ),
        ],
      ),
    );
  }
}
