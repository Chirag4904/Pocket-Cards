
import 'package:flutter/material.dart';
import '../models/wallet_card.dart';
import '../theme/card_skins.dart';

// List<String> cardBgs = [
//   'https://cdn.pixabay.com/photo/2022/12/01/04/40/backpacker-7628303_1280.jpg',
//   'https://c4.wallpaperflare.com/wallpaper/968/470/442/hatake-kakashi-naruto-anime-naruto-shippuuden-konoha-anime-boys-hd-wallpaper-preview.jpg',
//   'https://4kwallpapers.com/images/walls/thumbs_2t/896.jpg',
//   'https://img.freepik.com/free-photo/illustration-anime-city_23-2151779607.jpg?t=st=1737629223~exp=1737632823~hmac=3e5d6b9357df5075402816dbc21b52dd33f453cd6e800e35a1406c038cd5ec46&w=300'
// ];

class CardProvider extends ChangeNotifier {
  String _cardNumber = '';
  String _expiryDate = '';
  String _cardHolderName = '';
  String _cvv= '';
  String _selectedBank = '';
  String _cardColor = '0xFFFF0000';
  int _cardBG = 0;
  double _cardBalance = 0;
  String _skinId = CardSkins.defaultId;
  LogoStyle _logoStyle = LogoStyle.boxed;
  int? _billDay;
  int? _remindDaysBefore;

  /// Bumped when fields are filled from outside the text fields (an NFC
  /// scan), so the form can rebuild them with the new values.
  int _fillGeneration = 0;

  // Getter methods to access the fields
  String get cardNumber => _cardNumber;
  String get expiryDate => _expiryDate;
  String get cardHolderName => _cardHolderName;
  String get cvv => _cvv;
  String get selectedBank => _selectedBank;
  String get cardColor => _cardColor;
  double get cardBalance => _cardBalance;
  int get cardBG => _cardBG;
  String get skinId => _skinId;
  LogoStyle get logoStyle => _logoStyle;
  int? get billDay => _billDay;
  int? get remindDaysBefore => _remindDaysBefore;
  int get fillGeneration => _fillGeneration;

  void setBilling(int? billDay, int? remindDaysBefore) {
    _billDay = billDay;
    _remindDaysBefore = billDay == null ? null : remindDaysBefore;
    notifyListeners();
  }

  /// Fills what a contactless scan could read. Empty values are left alone.
  void fillFromScan({required String number, String? expiry, String? holder}) {
    _cardNumber = number;
    if (expiry != null && expiry.isNotEmpty) _expiryDate = expiry;
    if (holder != null && holder.isNotEmpty) _cardHolderName = holder;
    _fillGeneration++;
    notifyListeners();
  }

  void setLogoStyle(LogoStyle style) {
    _logoStyle = style;
    notifyListeners();
  }

  void setSkinId(String skinId) {
    _skinId = skinId;
    notifyListeners();
  }

  // Setter methods to update the fields and notify listeners
  void setCardNumber(String cardNumber) {
    _cardNumber = cardNumber;
    notifyListeners();
  }

  void setCardBG(int cardBGNum) {
    _cardBG = cardBGNum;
    notifyListeners();
  }

  void setCardBalance(double cardBalance) {
    _cardBalance = cardBalance;
    notifyListeners();
  }

  void setSelectedBank(String selectedBank) {
    _selectedBank = selectedBank;
    notifyListeners();
  }
  void setCardColor(String cardColor) {
    _cardColor = cardColor;
    notifyListeners();
  }

  void setExpiryDate(String expiryDate) {
    _expiryDate = expiryDate;
    notifyListeners();
  }

  void setCardHolderName(String cardHolderName) {
    _cardHolderName = cardHolderName;
    notifyListeners();
  }

  void setCVV(String cvvCode) {
    _cvv = cvvCode;
    notifyListeners();
  }

  void clearFields() {
    _cardNumber = '';
    _expiryDate = '';
    _cardHolderName = '';
    _cvv = '';
    _selectedBank = '';
    _cardColor = '0xFFFF0000';
    _cardBalance = 0;
    _cardBG = 0;
    _skinId = CardSkins.defaultId;
    _logoStyle = LogoStyle.boxed;
    _billDay = null;
    _remindDaysBefore = null;

    notifyListeners();
  }

}
