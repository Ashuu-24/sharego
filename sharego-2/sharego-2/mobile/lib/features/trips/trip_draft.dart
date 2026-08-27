import 'package:flutter_riverpod/legacy.dart';

class TripDraft {
  const TripDraft({
    this.country = 'Pakistan',
    this.airline = 'Saudia',
    this.originAirport = 'LHE',
    this.destinationAirport = 'RUH',
    this.eticketUrl = '',
    this.flightNumber = '',
    this.flightDate,
    this.capacityKg = '',
    this.feePerKg = '',
    this.expectedEarning = '',
    this.travelerName = '',
    this.travelerEmail = '',
    this.travelerPhone = '',
    this.travelerCnic = '',
    this.expMonth = '',
    this.expYear = '',
    this.createdTripId,
  });

  final String country;
  final String airline;
  final String originAirport;
  final String destinationAirport;
  final String eticketUrl;
  final String flightNumber;
  final DateTime? flightDate;
  final String capacityKg;
  final String feePerKg;
  final String expectedEarning;
  final String travelerName;
  final String travelerEmail;
  final String travelerPhone;
  final String travelerCnic;
  final String expMonth;
  final String expYear;
  final int? createdTripId;

  TripDraft copyWith({
    String? country,
    String? airline,
    String? originAirport,
    String? destinationAirport,
    String? eticketUrl,
    String? flightNumber,
    DateTime? flightDate,
    String? capacityKg,
    String? feePerKg,
    String? expectedEarning,
    String? travelerName,
    String? travelerEmail,
    String? travelerPhone,
    String? travelerCnic,
    String? expMonth,
    String? expYear,
    int? createdTripId,
  }) {
    return TripDraft(
      country: country ?? this.country,
      airline: airline ?? this.airline,
      originAirport: originAirport ?? this.originAirport,
      destinationAirport: destinationAirport ?? this.destinationAirport,
      eticketUrl: eticketUrl ?? this.eticketUrl,
      flightNumber: flightNumber ?? this.flightNumber,
      flightDate: flightDate ?? this.flightDate,
      capacityKg: capacityKg ?? this.capacityKg,
      feePerKg: feePerKg ?? this.feePerKg,
      expectedEarning: expectedEarning ?? this.expectedEarning,
      travelerName: travelerName ?? this.travelerName,
      travelerEmail: travelerEmail ?? this.travelerEmail,
      travelerPhone: travelerPhone ?? this.travelerPhone,
      travelerCnic: travelerCnic ?? this.travelerCnic,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
      createdTripId: createdTripId ?? this.createdTripId,
    );
  }
}

class TripDraftNotifier extends StateNotifier<TripDraft> {
  TripDraftNotifier() : super(TripDraft(flightDate: DateTime.now()));

  void updateFlight({
    required String country,
    required String airline,
    required String originAirport,
    required String destinationAirport,
    required DateTime flightDate,
    required String eticketUrl,
    String flightNumber = '',
  }) {
    state = state.copyWith(
      country: country,
      airline: airline,
      originAirport: originAirport,
      destinationAirport: destinationAirport,
      flightDate: flightDate,
      eticketUrl: eticketUrl.trim(),
      flightNumber: flightNumber.trim(),
    );
  }

  void updateCapacity({
    required String capacityKg,
    required String feePerKg,
    required String expectedEarning,
    required String travelerName,
    required String travelerEmail,
    required String travelerPhone,
    required String travelerCnic,
    required String expMonth,
    required String expYear,
  }) {
    state = state.copyWith(
      capacityKg: capacityKg.trim(),
      feePerKg: feePerKg.trim(),
      expectedEarning: expectedEarning.trim(),
      travelerName: travelerName.trim(),
      travelerEmail: travelerEmail.trim(),
      travelerPhone: travelerPhone.trim(),
      travelerCnic: travelerCnic.trim(),
      expMonth: expMonth.trim(),
      expYear: expYear.trim(),
    );
  }

  void setCreatedTripId(int id) {
    state = state.copyWith(createdTripId: id);
  }

  void reset() {
    state = TripDraft(flightDate: DateTime.now());
  }
}

final tripDraftProvider = StateNotifierProvider<TripDraftNotifier, TripDraft>(
  (ref) => TripDraftNotifier(),
);
