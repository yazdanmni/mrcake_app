import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';

class ProfileInfoSection extends StatefulWidget {
  const ProfileInfoSection({
    super.key,
    this.username,
    this.email,
    this.phoneNumber,
    this.onEditEmail,
  });

  final String? username;
  final String? email;
  final String? phoneNumber;
  final Future<bool> Function(String newEmail)? onEditEmail;

  @override
  State<ProfileInfoSection> createState() => _ProfileInfoSectionState();
}

class _ProfileInfoSectionState extends State<ProfileInfoSection> {
  final _emailFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSavingEmail = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void didUpdateWidget(ProfileInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email != widget.email && !_isSavingEmail) {
      _emailController.text = widget.email ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _showEditEmailDialog() async {
    _emailController.text = widget.email ?? '';
    _emailFormKey.currentState?.reset();

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.sectionBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                'ویرایش ایمیل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Form(
                key: _emailFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ایمیل جدید خود را وارد نمایید.',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'shabnam',
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'BShabnam',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.field,
                        hintText: 'example@email.com',
                        hintStyle: TextStyle(
                          fontFamily: 'shabnam',
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: 1.5.w,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: AppColors.border,
                            width: 1.5.w,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2.w,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 1.5.w,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: AppColors.error,
                            width: 2.w,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'ایمیل نمی‌تواند خالی باشد.';
                        }
                        if (!Validators.isEmailValid(v)) {
                          return 'ایمیل وارد شده معتبر نیست.';
                        }
                        return null;
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: OutlinedButton(
                            onPressed: _isSavingEmail
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.border,
                                width: 1.5.w,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: Text(
                              'انصراف',
                              style: TextStyle(
                                fontFamily: 'BShabnam',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: _isSavingEmail
                                ? null
                                : () async {
                                    if (!(_emailFormKey.currentState
                                            ?.validate() ??
                                        false)) {
                                      return;
                                    }
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    FocusScope.of(dialogContext).unfocus();

                                    setDialogState(() {
                                      _isSavingEmail = true;
                                    });

                                    final newEmail =
                                        _emailController.text.trim();
                                    bool ok = false;
                                    try {
                                      ok = await widget.onEditEmail
                                              ?.call(newEmail) ??
                                          false;
                                    } catch (_) {
                                      ok = false;
                                    }

                                    if (!mounted) return;
                                    setDialogState(() {
                                      _isSavingEmail = false;
                                    });

                                    navigator.pop(ok);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: _isSavingEmail
                                ? Center(
                                    child: SizedBox(
                                      width: 20.w,
                                      height: 20.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.w,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'ذخیره',
                                    style: TextStyle(
                                      fontFamily: 'BShabnam',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          margin: EdgeInsets.all(16.w),
          content: Text(
            'ایمیل با موفقیت به‌روزرسانی شد.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 13.sp,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          margin: EdgeInsets.all(16.w),
          content: Text(
            'ذخیره ایمیل ناموفق بود. دوباره تلاش کنید.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 13.sp,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            title: 'نام کاربری',
            value: widget.username ?? 'username',
            trailing: _StatusBox(
              text: 'قابل ویرایش نیست',
              icon: Icons.lock_outline_rounded,
            ),
          ),

          SizedBox(height: 18.h),

          _InfoRow(
            title: 'شماره تلفن',
            value: widget.phoneNumber ?? '09120000000',
            trailing: _StatusBox(
              text: 'قابل ویرایش نیست',
              icon: Icons.lock_outline_rounded,
            ),
          ),

          SizedBox(height: 18.h),

          _InfoRow(
            title: 'ایمیل',
            value: widget.email?.isNotEmpty == true
                ? widget.email!
                : 'ثبت نشده است',
            trailing: _ActionButton(
              text: 'درخواست ویرایش',
              icon: Icons.edit_outlined,
              onTap: widget.onEditEmail != null ? _showEditEmailDialog : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    required this.trailing,
  });

  final String title;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              SizedBox(height: 6.h),

              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 16.w),

        trailing,
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 9.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border,
          width: 1.w,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15.sp,
            color: AppColors.textSecondary,
          ),

          SizedBox(width: 6.w),

          Text(
            text,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.icon,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final primary =
        disabled ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 9.h,
          ),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: disabled ? 0.05 : 0.10),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: primary.withValues(alpha: disabled ? 0.15 : 0.30),
              width: 1.w,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: primary,
              ),

              SizedBox(width: 6.w),

              Text(
                text,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
