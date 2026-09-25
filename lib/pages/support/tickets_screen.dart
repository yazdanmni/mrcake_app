import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/repositories/profile_repository.dart';
import 'package:mr_cake_project/repositories/support_repository.dart';

class TicketSubject {
  final int id;
  final String title;

  const TicketSubject({
    required this.id,
    required this.title,
  });

  /// `TicketSubject` -> `GET /api/v1/support/subjects/`
  factory TicketSubject.fromJson(Map<String, dynamic> json) {
    return TicketSubject(
      id: Json.asInt(json['id']) ?? 0,
      title:
          Json.asString(json['name']) ??
              Json.asString(json['title']) ??
              '',
    );
  }
}

class TicketModel {
  final int id;
  final String subject;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? imagePath;

  const TicketModel({
    required this.id,
    required this.subject,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.imagePath,
  });

  /// `TicketList` / `TicketDetail` -> `GET /api/v1/support/my_tickets/`
  ///
  /// `subject` در بک‌اند یک آبجکت است، پس نام آن استخراج می‌شود.
  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final subject = Json.asMap(json['subject']);

    return TicketModel(
      id: Json.asInt(json['id']) ?? 0,

      subject:
          Json.asString(subject?['name']) ??
              Json.asString(json['subject']) ??
              '',

      title: Json.asString(json['title']) ?? '',
      description: Json.asString(json['description']) ?? '',
      status: Json.asString(json['status']) ?? 'open',
      createdAt:
          Json.asDate(json['created_at']) ??
              Json.asDate(json['updated_at']) ??
              DateTime.now(),
      imagePath: Json.asString(json['image_path']),
    );
  }
}

/// `TicketMessage` -> `messages[]` of `GET /api/v1/support/{id}/`.
///
/// This is where the **body** of a ticket lives. `TicketList` (the endpoint the
/// list screen reads) carries only `title` / `subject` / `status`, so a ticket
/// created automatically — for example by a paid course registration — shows its
/// details (name, family name, phone number, amounts) here and nowhere else.
class TicketMessage {
  final int id;
  final String message;
  final bool isAdmin;
  final String? attachment;
  final DateTime? createdAt;

  const TicketMessage({
    required this.id,
    required this.message,
    required this.isAdmin,
    this.attachment,
    this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: Json.asInt(json['id']) ?? 0,
      message: Json.asString(json['message']) ?? '',
      isAdmin: Json.asBool(json['is_admin']),
      attachment: Json.asString(json['attachment']),
      createdAt: Json.asDate(json['created_at']),
    );
  }
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  // ============================================================
  // SUBJECTS
  // ابتدا مقدار نمایشی، سپس پاسخ بک‌اند.
  // ============================================================

  List<TicketSubject> _subjects = const [
    TicketSubject(
      id: 1,
      title: 'مشکل در دوره',
    ),
    TicketSubject(
      id: 2,
      title: 'مشکل در پرداخت',
    ),
  ];

  // ============================================================
  // TICKETS
  // از `GET /api/v1/support/my_tickets/`.
  // ============================================================

  List<TicketModel> _tickets = [];

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    final subjectsRequest = RemoteLoader.list<TicketSubject>(
      label: 'support.subjects',
      seed: _subjects,
      fetch: () async {
        final page = await SupportRepository.instance.fetchSubjects();
        return page.map(TicketSubject.fromJson);
      },
    );

    final ticketsRequest = RemoteLoader.list<TicketModel>(
      label: 'support.tickets',
      seed: _tickets,
      fetch: () async {
        final page = await SupportRepository.instance.fetchMyTickets();
        return page.map(TicketModel.fromJson);
      },
    );

    final subjects = await subjectsRequest;
    final tickets = await ticketsRequest;

    if (!mounted) return;

    setState(() {
      _subjects = subjects.data;
      _tickets = tickets.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _tickets.isEmpty
                  ? _EmptyTickets(
                      onTap: _openCreateTicket,
                    )
                  : _TicketList(
                      tickets: _tickets,
                      onCreate: _openCreateTicket,
                      onTicketTap: _openTicket,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      height: 58.h,
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            splashRadius: 22.r,
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              size: 19.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            'پشتیبانی',
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE TICKET
  // ============================================================

  Future<void> _openCreateTicket() async {
    final TicketModel? ticket = await Navigator.push<TicketModel>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(
          subjects: _subjects,
        ),
      ),
    );

    if (ticket == null) return;

    setState(() {
      _tickets.insert(0, ticket);
    });
  }

  // ============================================================
  // TICKET DETAILS
  // ============================================================

  void _openTicket(TicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          ticket: ticket,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY TICKETS
// ============================================================================

class _EmptyTickets extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyTickets({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 25.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82.w,
              height: 82.w,
              decoration: BoxDecoration(
                color: AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: AppColors.premium,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                size: 40.sp,
                color: AppColors.premium,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'هنوز درخواستی ثبت نکرده‌اید',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 17.sp,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'در صورت نیاز می‌توانید درخواست پشتیبانی خود را ارسال کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 13.sp,
                height: 1.8,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 25.h),
            _CreateTicketButton(
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TICKET LIST
// ============================================================================

class _TicketList extends StatelessWidget {
  final List<TicketModel> tickets;
  final VoidCallback onCreate;
  final ValueChanged<TicketModel> onTicketTap;

  const _TicketList({
    required this.tickets,
    required this.onCreate,
    required this.onTicketTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(25.w, 22.h, 25.w, 30.h),
      children: [
        Row(
          
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'درخواست‌های من',
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 17.sp,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(
              height: 40.h,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.premium,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 13.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: Icon(
                  Icons.add_rounded,
                  size: 19.sp,
                ),
                label: Text(
                  'درخواست جدید',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 18.h),
        ...tickets.map(
          (ticket) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _TicketCard(
              ticket: ticket,
              onTap: () => onTicketTap(ticket),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TICKET CARD
// ============================================================================

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = ticket.status == 'open';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(15.w),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 45.w,
                height: 45.w,
                decoration: BoxDecoration(
                  color: AppColors.sectionBackground,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.premium,
                  size: 23.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'pinarb',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 9.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.primary.withValues(alpha: .16)
                      : AppColors.premium.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Text(
                  isOpen ? 'در حال بررسی' : 'بسته شده',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 10.sp,
                    color: isOpen
                        ? AppColors.primary
                        : AppColors.premium,
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Icon(
                Icons.chevron_left_rounded,
                size: 22.sp,
                color: AppColors.placeholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CREATE TICKET SCREEN
// ============================================================================

class CreateTicketScreen extends StatefulWidget {
  final List<TicketSubject> subjects;

  const CreateTicketScreen({
    super.key,
    required this.subjects,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  TicketSubject? _selectedSubject;

  XFile? _attachment;

  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _attachment = image;
    });
  }

  // ============================================================
  // SEND
  // ============================================================

  Future<void> _sendTicket() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubject == null) {
      _showError('لطفاً موضوع درخواست را انتخاب کنید.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    // ==========================================================
    // آپلود پیوست (اختیاری) و سپس ثبت درخواست در بک‌اند
    // ==========================================================

    String? attachmentUrl;

    final attachment = _attachment;

    if (attachment != null) {
      try {
        attachmentUrl = await MediaRepository.instance.uploadUrl(
          File(attachment.path),
        );
      } on ApiException {
        // پیوست مهم‌تر از خود درخواست نیست، پس ارسال ادامه پیدا می‌کند.
        attachmentUrl = null;
      }
    }

    // `POST /api/v1/support/`
    final created = await RemoteLoader.action(
      'support.create',
      () => SupportRepository.instance.createTicket(
        title: title,
        message: description,
        subjectId: _selectedSubject!.id,
        attachment: attachmentUrl,
      ),
    );

    if (!mounted) return;

    if (!created) {
      setState(() {
        _isSending = false;
      });

      _showError('ارسال درخواست ناموفق بود. دوباره تلاش کنید.');

      return;
    }

    final TicketModel ticket = TicketModel(
      id: DateTime.now().millisecondsSinceEpoch,
      subject: _selectedSubject!.title,
      title: title,
      description: description,
      status: 'open',
      createdAt: DateTime.now(),
      imagePath: _attachment?.path,
    );

    Navigator.pop(context, ticket);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'bshabnam',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    25.w,
                    20.h,
                    25.w,
                    30.h,
                  ),
                  children: [
                    _buildSubject(),
                    SizedBox(height: 17.h),
                    _buildTitle(),
                    SizedBox(height: 17.h),
                    _buildDescription(),
                    SizedBox(height: 17.h),
                    _buildAttachment(),
                    SizedBox(height: 28.h),
                    _buildSendButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      height: 58.h,
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            splashRadius: 22.r,
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              size: 19.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            'ارسال درخواست',
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBJECT
  // ============================================================

  Widget _buildSubject() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(
          title: 'موضوع درخواست',
          requiredField: true,
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<TicketSubject>(
          value: _selectedSubject,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.premium,
            size: 24.sp,
          ),
          dropdownColor: AppColors.field,
          decoration: _inputDecoration(
            hint: 'موضوع درخواست را انتخاب کنید',
          ),
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 13.sp,
            color: AppColors.textPrimary,
          ),
          items: widget.subjects
              .map(
                (subject) => DropdownMenuItem<TicketSubject>(
                  value: subject,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      subject.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubject = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'انتخاب موضوع الزامی است';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(
          title: 'عنوان درخواست',
          requiredField: true,
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _titleController,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          maxLength: 100,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 13.sp,
            color: AppColors.textPrimary,
          ),
          decoration: _inputDecoration(
            hint: 'عنوان درخواست را وارد کنید',
          ).copyWith(
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'عنوان درخواست الزامی است';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(
          title: 'توضیحات',
          requiredField: true,
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _descriptionController,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          minLines: 6,
          maxLines: 9,
          maxLength: 1000,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 13.sp,
            height: 1.8,
            color: AppColors.textPrimary,
          ),
          decoration: _inputDecoration(
            hint: 'توضیحات درخواست خود را وارد کنید',
          ).copyWith(
            contentPadding: EdgeInsets.all(15.w),
            counterStyle: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 10.sp,
              color: AppColors.placeholder,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'توضیحات الزامی است';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ============================================================
  // ATTACHMENT
  // ============================================================

  Widget _buildAttachment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldTitle(
          title: 'پیوست تصویر',
          requiredField: false,
        ),
        SizedBox(height: 8.h),
        if (_attachment == null)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 105.h,
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 29.sp,
                    color: AppColors.premium,
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    'افزودن تصویر',
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _AttachmentPreview(
            image: File(_attachment!.path),
            onRemove: () {
              setState(() {
                _attachment = null;
              });
            },
          ),
      ],
    );
  }

  // ============================================================
  // SEND BUTTON
  // ============================================================

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendTicket,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.premium,
          disabledBackgroundColor: AppColors.premium.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: _isSending
            ? SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Text(
                'ارسال درخواست',
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      hintStyle: TextStyle(
        fontFamily: 'bshabnam',
        fontSize: 12.sp,
        color: AppColors.placeholder,
      ),
      filled: true,
      fillColor: AppColors.field,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 15.w,
        vertical: 14.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: AppColors.premium,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: Colors.redAccent.withValues(alpha: .7),
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
      errorStyle: TextStyle(
        fontFamily: 'bshabnam',
        fontSize: 10.sp,
      ),
    );
  }
}

// ============================================================================
// FIELD TITLE
// ============================================================================

class _FieldTitle extends StatelessWidget {
  final String title;
  final bool requiredField;

  const _FieldTitle({
    required this.title,
    required this.requiredField,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'pinarb',
            fontSize: 13.sp,
            color: AppColors.textPrimary,
          ),
        ),
        if (requiredField) ...[
          SizedBox(width: 4.w),
          Text(
            '*',
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 14.sp,
              color: AppColors.premium,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// ATTACHMENT PREVIEW
// ============================================================================

class _AttachmentPreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: Image.file(
            image,
            width: double.infinity,
            height: 180.h,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8.h,
          left: 8.w,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CREATE BUTTON
// ============================================================================

class _CreateTicketButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTicketButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.premium,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
        ),
        icon: Icon(
          Icons.add_rounded,
          size: 21.sp,
        ),
        label: Text(
          'ارسال درخواست',
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TICKET DETAILS
// ============================================================================

class TicketDetailsScreen extends StatefulWidget {
  final TicketModel ticket;

  const TicketDetailsScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  List<TicketMessage> _messages = const <TicketMessage>[];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// `GET /api/v1/support/{id}/` -> `TicketDetail`.
  ///
  /// The list endpoint the previous screen read from returns no message body,
  /// which is why the «توضیحات» box used to be empty for **every** ticket. The
  /// body is what matters here: a ticket this app creates by itself (a paid
  /// course registration) carries the user's name, family name and phone number
  /// in it, and the user has to be able to read it back.
  Future<void> _load() async {
    try {
      final detail = await SupportRepository.instance.fetchTicket(
        widget.ticket.id,
      );

      final raw = detail['messages'];
      final messages = raw is List
          ? raw
                .map(Json.asMap)
                .whereType<Map<String, dynamic>>()
                .map(TicketMessage.fromJson)
                .toList(growable: false)
          : const <TicketMessage>[];

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (error) {
      debugPrint('[Ticket] detail fetch failed: $error');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              height: 58.h,
              decoration: BoxDecoration(
                color: AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.ltr,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 22.r,
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 19.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      'درخواست #${ticket.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'pinarb',
                        fontSize: 17.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(25.w),
                children: [
                  _DetailBox(
                    title: 'موضوع',
                    child: Text(
                      ticket.subject,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _DetailBox(
                    title: 'عنوان درخواست',
                    child: Text(
                      ticket.title,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'pinarb',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  else if (_messages.isEmpty)
                    // Nothing came back (or the request failed): keep showing
                    // whatever the list screen handed over.
                    _DetailBox(
                      title: 'توضیحات',
                      child: Text(
                        ticket.description,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 13.sp,
                          height: 1.9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ..._messages.map(
                      (message) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _MessageBox(message: message),
                      ),
                    ),
                  if (ticket.imagePath != null) ...[
                    SizedBox(height: 12.h),
                    _DetailBox(
                      title: 'پیوست',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.file(
                          File(ticket.imagePath!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE BOX
// ============================================================================

/// One entry of `TicketDetail.messages`.
///
/// Rendered through the same [_DetailBox] the rest of the screen uses, so an
/// automatically created registration ticket looks like every other ticket.
class _MessageBox extends StatelessWidget {
  final TicketMessage message;

  const _MessageBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isAdmin;

    return _DetailBox(
      title: isAdmin ? 'پاسخ پشتیبانی' : 'پیام شما',
      child: Text(
        message.message,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 13.sp,
          height: 1.9,
          color: isAdmin ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ============================================================================
// DETAIL BOX
// ============================================================================

class _DetailBox extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailBox({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 13.sp,
              color: AppColors.premium,
            ),
          ),
          SizedBox(height: 9.h),
          child,
        ],
      ),
    );
  }
}