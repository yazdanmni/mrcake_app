import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import 'catalog_repository.dart';
import 'support_repository.dart';

/// The in-app credit («اعتبار») flow.
///
/// ## Why it rides on a support ticket
///
/// There is **no wallet endpoint** on this backend — no balance field, no
/// top-up route, no payment gateway that can settle one (`mock_gateway` answers
/// `404 شناسه پرداخت یافت نشد` for every body). What the product actually does is
/// manual: the user asks for credit, an admin tops the account up and closes the
/// ticket.
///
/// So the whole lifecycle is modelled on **one ticket**:
///
///   * asking for credit  → `POST v1/support/` with a marked title,
///   * the request's state → the ticket's `status` (`open` → `closed`),
///   * "the credit landed" → the ticket being `closed`, which the screen reads
///     as «شارژ انجام شده».
///
/// ## Why the requests are kept off the tickets screen
///
/// A top-up request is not a support conversation — showing it in «تیکت‌ها»
/// would bury real support issues under bookkeeping, and the user asked
/// explicitly for it not to appear there. The marker in the title is what lets
/// the tickets screen filter them out, and its inverse is what lets this screen
/// find them again without a second endpoint.
class WalletRepository {
  WalletRepository._();

  static final WalletRepository instance = WalletRepository._();

  SupportRepository get _support => SupportRepository.instance;

  /// Every wallet request's title starts with this marker.
  ///
  /// A prefix on the title rather than a subject, because subjects are admin-
  /// editable data and a wrong id would silently re-point every request. The
  /// marker is invisible in the UI: [WalletRequest.displayTitle] strips it.
  static const String marker = '[wallet]';

  static const String requestTitle = '$marker درخواست شارژ اعتبار';

  /// The smallest sensible top-up, and the step the quick amounts use.
  static const int minAmount = 50000;
  static const int quickStep = 100000;

  /// The preset buttons, in order.
  static const List<int> quickAmounts = <int>[
    50000,
    100000,
    200000,
    500000,
  ];

  /// Files a top-up request for [amount] tomans.
  ///
  /// The amount, the requester's identity and the intent all go into the message
  /// body, because `TicketList` (what both screens read) carries only the title
  /// and status — the body is the one place the admin can see what was asked
  /// for. Returns the created ticket id, or `null` when the request failed.
  Future<int?> requestTopUp({
    required int amount,
    required String fullName,
    required String phone,
  }) async {
    if (amount < minAmount) return null;

    final String message = <String>[
      '$marker درخواست شارژ اعتبار حساب',
      '',
      'مبلغ درخواستی: ${_toman(amount)}',
      if (fullName.trim().isNotEmpty) 'نام و نام خانوادگی: ${fullName.trim()}',
      if (phone.trim().isNotEmpty) 'شماره تماس: ${phone.trim()}',
      '',
      'این درخواست به صورت خودکار از صفحه «اعتبار شما» ثبت شده است.',
      'پس از شارژ، لطفاً این درخواست را ببندید تا وضعیت «شارژ انجام شده» شود.',
    ].join('\n');

    try {
      final created = await _support.createTicket(
        title: requestTitle,
        message: message,
        priority: TicketPriority.high,
      );

      final int? id = Json.asInt(created['id']);
      return id != null && id > 0 ? id : null;
    } catch (_) {
      return null;
    }
  }

  /// Every wallet request this user has filed, newest first.
  ///
  /// Read from `GET v1/support/my_tickets/` and filtered on the marker, so no
  /// extra endpoint is needed. The list endpoint carries the status, which is
  /// the only thing this screen needs to decide between «در انتظار بررسی» and
  /// «شارژ انجام شده».
  Future<List<WalletRequest>> fetchRequests({int page = 1}) async {
    final PagedResult page1 = await _support.fetchMyTickets(page: page);

    final List<WalletRequest> requests = <WalletRequest>[];

    for (final Map<String, dynamic> json in page1.items) {
      final WalletRequest? request = WalletRequest.fromTicketJson(json);
      if (request != null) requests.add(request);
    }

    requests.sort(
      (WalletRequest a, WalletRequest b) => b.createdAt.compareTo(a.createdAt),
    );

    return requests;
  }

  /// The amount parsed back out of a ticket body, for the cards.
  ///
  /// `null` when the body does not carry a parsable amount — the request still
  /// shows, it just cannot print a figure.
  static final RegExp _amountPattern = RegExp(
    r'مبلغ درخواستی:\s*([0-9۰-۹,٬]+)',
  );

  static int? parseAmount(String body) {
    final RegExpMatch? match = _amountPattern.firstMatch(body);
    if (match == null) return null;

    final String digits = _toEnglishDigits(match.group(1)!)
        .replaceAll(',', '')
        .replaceAll('٬', '');

    return int.tryParse(digits);
  }

  static String _toEnglishDigits(String value) {
    const String persian = '۰۱۲۳۴۵۶۷۸۹';
    const String arabic = '٠١٢٣٤٥٦٧٨٩';
    const String english = '0123456789';

    String result = value;

    for (int i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], english[i]);
    }

    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }

    return result;
  }

  static String _toman(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }

    return '$buffer تومان';
  }

  /// The endpoint the wallet screen would read a balance from, if the backend
  /// had one.
  ///
  /// Kept as a constant so the "there is no wallet endpoint" fact is written
  /// down once, next to the code that would use it. `v1/accounts/users/me/` is
  /// the closest thing that exists — and it carries **no balance field**, which
  /// is why the screen derives its state from the tickets instead.
  static const String balanceEndpoint = ApiEndpoints.usersMe;
}

/// One «اعتبار شما» request, as the wallet screen needs it.
class WalletRequest {
  const WalletRequest({
    required this.ticketId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.closedAt,
    required this.amount,
  });

  /// The id of the ticket the request lives on.
  final int ticketId;

  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;

  /// Parsed from the ticket body; `null` when the body has no amount.
  final int? amount;

  /// An admin finished with it — which for a top-up means the credit landed.
  bool get isCompleted => TicketStatus.isFinished(status);

  /// The title without the internal marker, ready to print.
  String get displayTitle =>
      title.replaceFirst(WalletRepository.marker, '').trim();

  /// The state, in the words the screen uses.
  String get statusLabel =>
      isCompleted ? 'شارژ انجام شده' : TicketStatus.label(status);

  /// `null` when the row is not a wallet request — the filter, in one place.
  static WalletRequest? fromTicketJson(Map<String, dynamic> json) {
    final String title = Json.asString(json['title']) ?? '';

    if (!title.contains(WalletRepository.marker)) return null;

    return WalletRequest(
      ticketId: Json.asInt(json['id']) ?? 0,
      title: title,
      status: Json.asString(json['status']) ?? TicketStatus.open,
      createdAt:
          Json.asDate(json['created_at']) ??
          Json.asDate(json['updated_at']) ??
          DateTime.now(),
      closedAt: Json.asDate(json['closed_at']),
      amount: null,
    );
  }

  /// A copy carrying the amount parsed from the ticket's messages.
  WalletRequest withAmount(int? value) => WalletRequest(
    ticketId: ticketId,
    title: title,
    status: status,
    createdAt: createdAt,
    closedAt: closedAt,
    amount: value ?? amount,
  );
}
