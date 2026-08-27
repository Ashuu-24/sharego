import 'package:flutter_riverpod/legacy.dart';

class BookingDraft {
  const BookingDraft({
    this.fromCity = 'LHE',
    this.toCity = 'RUH',
    required this.selectedDate,
    this.weightKg = 5.0,
    this.selectedTripIdRaw = '',
    this.senderName = '',
    this.senderEmail = '',
    this.senderPhone = '',
    this.itemName = '',
    this.itemWeight = '',
    this.itemDescription = '',
    this.itemPrice = '',
    this.createdRequestId,
    this.createdBookingId,
    this.pickupOtpDev,
    this.deliveryOtpDev,
  });

  final String fromCity;
  final String toCity;
  final DateTime selectedDate;
  final double weightKg;
  final String selectedTripIdRaw;
  final String senderName;
  final String senderEmail;
  final String senderPhone;
  final String itemName;
  final String itemWeight;
  final String itemDescription;
  final String itemPrice;
  final int? createdRequestId;
  final int? createdBookingId;
  final String? pickupOtpDev;
  final String? deliveryOtpDev;

  int? get selectedTripId {
    final direct = int.tryParse(selectedTripIdRaw);
    if (direct != null) return direct;
    final digits = RegExp(r'\d+').firstMatch(selectedTripIdRaw)?.group(0);
    return digits == null ? null : int.tryParse(digits);
  }

  BookingDraft copyWith({
    String? fromCity,
    String? toCity,
    DateTime? selectedDate,
    double? weightKg,
    String? selectedTripIdRaw,
    String? senderName,
    String? senderEmail,
    String? senderPhone,
    String? itemName,
    String? itemWeight,
    String? itemDescription,
    String? itemPrice,
    int? createdRequestId,
    int? createdBookingId,
    String? pickupOtpDev,
    String? deliveryOtpDev,
  }) {
    return BookingDraft(
      fromCity: fromCity ?? this.fromCity,
      toCity: toCity ?? this.toCity,
      selectedDate: selectedDate ?? this.selectedDate,
      weightKg: weightKg ?? this.weightKg,
      selectedTripIdRaw: selectedTripIdRaw ?? this.selectedTripIdRaw,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      senderPhone: senderPhone ?? this.senderPhone,
      itemName: itemName ?? this.itemName,
      itemWeight: itemWeight ?? this.itemWeight,
      itemDescription: itemDescription ?? this.itemDescription,
      itemPrice: itemPrice ?? this.itemPrice,
      createdRequestId: createdRequestId ?? this.createdRequestId,
      createdBookingId: createdBookingId ?? this.createdBookingId,
      pickupOtpDev: pickupOtpDev ?? this.pickupOtpDev,
      deliveryOtpDev: deliveryOtpDev ?? this.deliveryOtpDev,
    );
  }
}

class BookingDraftNotifier extends StateNotifier<BookingDraft> {
  BookingDraftNotifier()
      : super(BookingDraft(
          selectedDate: DateTime.now(),
        ));

  void updateSearch({
    required String fromCity,
    required String toCity,
    required DateTime selectedDate,
    required double weightKg,
  }) {
    state = state.copyWith(
      fromCity: fromCity,
      toCity: toCity,
      selectedDate: selectedDate,
      weightKg: weightKg,
    );
  }

  void selectTrip(String tripIdRaw) {
    state = state.copyWith(selectedTripIdRaw: tripIdRaw);
  }

  void updateDetails({
    required String senderName,
    required String senderEmail,
    required String senderPhone,
    required String itemName,
    required String itemWeight,
    required String itemDescription,
    required String itemPrice,
  }) {
    state = state.copyWith(
      senderName: senderName.trim(),
      senderEmail: senderEmail.trim(),
      senderPhone: senderPhone.trim(),
      itemName: itemName.trim(),
      itemWeight: itemWeight.trim(),
      itemDescription: itemDescription.trim(),
      itemPrice: itemPrice.trim(),
    );
  }

  void setCreatedData({
    required int requestId,
    required int bookingId,
    String? pickupOtpDev,
    String? deliveryOtpDev,
  }) {
    state = state.copyWith(
      createdRequestId: requestId,
      createdBookingId: bookingId,
      pickupOtpDev: pickupOtpDev,
      deliveryOtpDev: deliveryOtpDev,
    );
  }

  void reset() {
    state = BookingDraft(selectedDate: DateTime.now());
  }
}

final bookingDraftProvider =
    StateNotifierProvider<BookingDraftNotifier, BookingDraft>(
  (ref) => BookingDraftNotifier(),
);
