import 'package:flutter/material.dart';

class MockData {
  static final user = {
    'name': 'Mr. Hassan',
    'location': 'Lahore, Pakistan',
    'rating': 4.6,
    'kycStatus': 'Approved',
  };

  static final trips = [
    {
      'id': '1',
      'traveler': 'Humayun Raza',
      'rating': 4.6,
      'reviews': 1344,
      'route': 'Lahore → Riyadh',
      'fromAirport': 'Allama Iqbal International Airport, Lahore',
      'toAirport': 'King Khalid International Airport, Riyadh',
      'time': '27/10/2025 10:00 AM',
      'capacity': '6 kg',
      'rate': 'Rs. 1500',
      'userBudget': 'Rs. 80,000',
    },
    {
      'id': '2',
      'traveler': 'Haider Goraya',
      'rating': 4.3,
      'reviews': 765,
      'route': 'Lahore → Dubai',
      'fromAirport': 'Allama Iqbal International Airport, Lahore',
      'toAirport': 'Dubai International Airport',
      'time': '30/10/2025 09:00 AM',
      'capacity': '8 kg',
      'rate': 'Rs. 1800',
      'userBudget': 'Rs. 90,000',
    },
  ];

  static final bookings = [
    {
      'id': 'BKG-12345',
      'tripId': '1',
      'status': 'HOLD',
      'timeline': [
        {'title': 'Booking Created', 'subtitle': 'Hold placed', 'time': 'Today 10:00'},
        {'title': 'Pickup OTP Pending', 'subtitle': 'Share with traveler', 'time': ''},
      ],
    },
  ];

  static final listings = [
    {
      'id': 'LST-100',
      'title': 'Apple MacBook Pro',
      'price': 'Rs. 150,000',
      'seller': 'Ameer Tufail',
      'rating': 4.7,
      'lastOffer': 'Rs. 145,000',
      'status': 'ACTIVE',
      'desc': 'Brand New, Sealed',
      'condition': 'Brand New',
      'location': 'Lahore, Pakistan',
    },
    {
      'id': 'LST-200',
      'title': 'PS5 Disk Edition',
      'price': 'Rs. 120,000',
      'seller': 'Sara Khan',
      'rating': 4.5,
      'lastOffer': 'Rs. 115,000',
      'status': 'ACTIVE',
      'desc': 'Gently used, with box',
      'condition': 'Used',
      'location': 'Karachi, Pakistan',
    },
  ];

  static final offers = [
    {
      'id': 'OF-1',
      'listingId': 'LST-100',
      'amount': 'Rs. 145,000',
      'message': 'Can pick up on weekend',
      'by': 'Buyer',
      'status': 'countered',
      'time': 'Yesterday',
    },
    {
      'id': 'OF-2',
      'listingId': 'LST-100',
      'amount': 'Rs. 150,000',
      'message': 'Final offer, deal?',
      'by': 'Seller',
      'status': 'sent',
      'time': 'Today',
    },
  ];

  static final chats = [
    {
      'id': 'CHAT-1',
      'title': 'Booking BKG-12345',
      'messages': [
        {'from': 'Traveler', 'text': 'Please share OTP at pickup point.', 'time': '10:00'},
        {'from': 'You', 'text': 'Sure, meeting at LHE main gate.', 'time': '10:02'},
      ],
    },
    {
      'id': 'CHAT-2',
      'title': 'Listing Apple MacBook Pro',
      'messages': [
        {'from': 'Seller', 'text': 'Price is firm at 150k.', 'time': '09:00'},
        {'from': 'You', 'text': 'I can do 145k with meetup today.', 'time': '09:05'},
      ],
    },
  ];

  static final issues = [
    {
      'id': 'ISS-1',
      'title': 'Pickup OTP mismatch',
      'type': 'OTP',
      'status': 'Open',
      'reportedBy': 'Buyer',
      'ref': 'BKG-12345',
      'timeline': [
        {'title': 'Issue opened', 'time': 'Today 09:00'},
        {'title': 'Waiting for traveler', 'time': 'Today 09:10'},
      ],
      'notes': 'Traveler entered wrong OTP twice.',
    },
    {
      'id': 'ISS-2',
      'title': 'Price changed mid-deal',
      'type': 'Marketplace',
      'status': 'Pending',
      'reportedBy': 'Buyer',
      'ref': 'LST-100',
      'timeline': [
        {'title': 'Issue opened', 'time': 'Yesterday'},
        {'title': 'Waiting for admin', 'time': 'Today'},
      ],
      'notes': 'Seller increased price after agreement.',
    },
  ];

  static final aiResponses = {
    'What is escrow?':
        'Escrow holds funds for Personal Shopping bookings until pickup and delivery OTPs are verified.',
    'Show my bookings': 'You have 1 active booking: BKG-12345 (HOLD).',
    'Does Flyro deliver marketplace items?': 'Marketplace is peer-to-peer; delivery/payment handled off-platform.',
  };

  static List<String> get cities => ['Lahore', 'Karachi', 'Islamabad'];

  static Color get accent => Colors.blue;

  static bool offline = false;
}
