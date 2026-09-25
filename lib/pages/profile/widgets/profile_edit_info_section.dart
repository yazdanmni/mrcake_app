import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class ProfileEditInfoSection extends StatefulWidget {
  const ProfileEditInfoSection({
    super.key,
    this.firstName,
    this.lastName,
    this.onSave,
  });

  final String? firstName;
  final String? lastName;
  final void Function(String firstName, String lastName)? onSave;

  @override
  State<ProfileEditInfoSection> createState() =>
      _ProfileEditInfoSectionState();
}

class _ProfileEditInfoSectionState
    extends State<ProfileEditInfoSection> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();

    _firstNameController = TextEditingController(
      text: widget.firstName ?? 'یزدان',
    );

    _lastNameController = TextEditingController(
      text: widget.lastName ?? 'منوچهری',
    );
  }

  @override
  void didUpdateWidget(ProfileEditInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    _syncController(_firstNameController, widget.firstName);
    _syncController(_lastNameController, widget.lastName);
  }

  void _syncController(TextEditingController controller, String? value) {
    if (value == null || value.isEmpty) return;
    if (controller.text == value) return;

    controller.text = value;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();

    super.dispose();
  }

  void _saveInformation() {
    FocusScope.of(context).unfocus();

    widget.onSave?.call(
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        children: [
          _ProfileEditRow(
            label: ':نام',
            controller: _firstNameController,
          ),

          SizedBox(height: 7.h),

          _ProfileEditRow(
            label: ':نام خانوادگی',
            controller: _lastNameController,
          ),

          SizedBox(height: 14.h),

          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: _saveInformation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'ذخیره تغییرات',
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 226.w,
              ),
              height: 50.h,
              margin: EdgeInsets.only(left: 10.w),
              child: TextField(
                controller: controller,
                keyboardType:
                    keyboardType ?? TextInputType.text,
                inputFormatters: inputFormatters,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.field,

                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                  ),

                  suffixIcon: Icon(
                    Icons.edit_rounded,
                    size: 19.sp,
                    color: AppColors.textSecondary,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(
                      color: AppColors.border,
                      width: 2.w,
                    ),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(
                      color: AppColors.border,
                      width: 2.w,
                    ),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 2.w,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
