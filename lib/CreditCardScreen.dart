import 'package:flutter/material.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:provider/provider.dart';
import 'package:u_credit_card/u_credit_card.dart';
import 'secure_card_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';



class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formattedText = newText
        .replaceAllMapped(
          RegExp(r".{4}"),
          (match) => "${match.group(0)} ",
        )
        .trim();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length > 2) {
      text = text.substring(0, 2) + '/' + text.substring(2);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CreditCardScreen extends StatefulWidget {
  @override
  _CreditCardScreenState createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  late Future<List<Map<String, String>>> _cards;

  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> bankMapping = {};
  String? selectedBank;

  @override
  void initState() {
    super.initState();
    _cards = _storageService.getCards();
    loadBankMapping();
  }

  Future<void> _addCard(
      String cardNumber,
      String cardHolderName,
      String expiryDate,
      String cvvCode,
      String bank,
      String cardBG,
      double cardBalance) async {

      await _storageService.addCard(cardNumber, cardHolderName, expiryDate,
          cvvCode, bank, cardBG, cardBalance);
      setState(() {
        _cards = _storageService.getCards();
      });

  }

  void _deleteCard(int index) async {
    await _storageService.deleteCard(index);
    setState(() {
      _cards = _storageService.getCards();
    });
  }

  Future<void> loadBankMapping() async {
    try {
      // Load the JSON file from assets
      final String response =
          await rootBundle.loadString('assets/bank_mapping.json');
      final data = await json.decode(response);

      setState(() {
        bankMapping = data;
      });
    } catch (e) {
      print('Error loading bank mapping: $e');
    }
  }

  void _copyCardDetails(String details) {
    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card details copied to clipboard')));
  }

  void _showCardDetails(Map<String, String> card, int index) {
    print(card);
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CreditCardUi(
                width: MediaQuery.of(context).size.width * 0.9,
                cardHolderFullName: card['card_holder_name']!,
                cardNumber: card['card_number']!,
                validThru: card['expiry_date']!,
                cvvNumber: card['cvv'],
                enableFlipping: true,
                shouldMaskCardNumber: false,
                topLeftColor: Colors.red,
                backgroundDecorationImage: int.parse(card['cardBG']?? '0') >0 ?DecorationImage(
                  // image: Image.network('https://cdn.pixabay.com/photo/2022/12/01/04/40/backpacker-7628303_1280.jpg').image,
                  image: Image.asset('assets/cardBG${card['cardBG']}.jpg').image,
                  fit: BoxFit.cover,
                ):null,
                cardType: CardType.credit,
                showValidFrom: false,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      icon: Icon(Icons.copy, color: Colors.white),
                      onPressed: () => _copyCardDetails(
                          'Card Number: ${card['card_number']}, Expiry: ${card['expiry_date']}, CVV: ${card['cvv']}')),
                  SizedBox(width: 20),
                  IconButton(
                      icon: Icon(Icons.delete, color: Colors.white),
                      onPressed: () =>
                          {Navigator.pop(context), _deleteCard(index)}),
                ],
              )
            ],
          ),
          // actions: [
          //   TextButton(
          //     child: Text('Close'),
          //     onPressed: () => Navigator.pop(context),
          //   ),
          // ],
        );
      },
    );
  }

  Widget buildContainer(int bgNum, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'XXXX XXXX XXXX XXXX',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 4,
                  fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Valid MM/YY',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 2,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 18,
                ),
              ],
            ),
            SizedBox(
              height: 2,
            ),
            Text(
              'CARD HOLDER NAME',
              textAlign: TextAlign.start,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 3,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 6,
            )
          ],
        ),
        padding: EdgeInsetsDirectional.only(start: 5),
        alignment: Alignment.centerLeft,
        width: 65,
        height: 35,
        decoration: BoxDecoration(
          image: DecorationImage(image: Image.asset('assets/cardBG${bgNum}.jpg').image,fit: BoxFit.cover),
          borderRadius: BorderRadius.circular(8),

        ),
      ),
    );
  }

  void _showAddCardDialog() {
    setState(() {
      cardNumber = '';
      expiryDate = '';
      cardHolderName = '';
      cvvCode = '';
      selectedBank = null;
    });

    showDialog(
      context: context,
      builder: (context) {
        return Consumer<CardProvider>(builder: (context, provider, child) {
          return AlertDialog(
            contentPadding: EdgeInsets.all(16),
            title: Text("Add New Card"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CreditCardUi(
                    // width: MediaQuery.of(context).size.width * 0.7,
                    cardHolderFullName: provider.cardHolderName.isEmpty
                        ? 'Card Holder Name'
                        : provider.cardHolderName,
                    cardNumber: provider.cardNumber.isEmpty
                        ? 'XXXXXXXXXXXXXXXX'
                        : provider.cardNumber,
                    validThru: provider.expiryDate.isEmpty
                        ? 'MM/YY'
                        : provider.expiryDate,
                    cvvNumber: provider.cvv.isEmpty ? '000' : provider.cvv,
                    enableFlipping: true,
                    topLeftColor: Colors.red,
                    backgroundDecorationImage: provider.cardBG > 0 ? DecorationImage(
                      image: Image.asset('assets/cardBG${provider.cardBG}.jpg').image,
                      fit: BoxFit.cover,
                    ): null,
                    currencySymbol: '₹',
                    // bottomRightColor: Colors.lightGreen,
                    showValidFrom: false,
                    showBalance: true,
                    balance: provider.cardBalance,
                    cardType: CardType.credit,
                    creditCardType: CreditCardType.visa,
                    cardProviderLogo:
                        bankMapping.containsKey(provider.selectedBank)
                            ? Image.network(
                                'https://raw.githubusercontent.com/Chirag4904/indian-banks/refs/heads/main/assets/logos/${bankMapping[provider.selectedBank]}/logo.png',
                                height: 10,
                              )
                            : null,
                    shouldMaskCardNumber: false,
                  ),
                  SizedBox(height: 16),
                  Row(
                    // mainAxisSize: MainAxisSize.max,

                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildContainer(
                          1,
                          () => provider.setCardBG(1),),
                      buildContainer(
                          2,
                          () => provider.setCardBG(2),),
                      buildContainer(
                          3,
                          () => provider.setCardBG(3),),
                      buildContainer(
                          4,
                          () => provider.setCardBG(4),)
                    ],
                  ),
                  SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedBank,
                          decoration: InputDecoration(
                            labelText: 'Select Bank',
                            border: OutlineInputBorder(),
                          ),
                          items: bankMapping.keys.map((String bank) {
                            return DropdownMenuItem<String>(
                              value: bank,
                              child: Text(bank),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedBank = newValue;
                              provider.setSelectedBank(newValue!);
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a bank' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: provider.cardNumber,
                          decoration: InputDecoration(
                            labelText: 'Card Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(16),
                            CardNumberInputFormatter(),
                          ],
                          onChanged: (value) => provider.setCardNumber(value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter card number';
                            }
                            final cleanedValue =
                                value.replaceAll(RegExp(r'\s+'), '');
                            if (cleanedValue.length != 16) {
                              return 'Card number must be 16 digits';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: provider.expiryDate,
                                decoration: InputDecoration(
                                  labelText: 'Expiry (MM/YY)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  ExpiryDateInputFormatter(),
                                ],
                                onChanged: (value) =>
                                    provider.setExpiryDate(value),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter expiry date';
                                  }
                                  final regex =
                                      RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
                                  if (!regex.hasMatch(value)) {
                                    return 'Invalid expiry date (MM/YY)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    provider.cardBalance.toInt().toString(),
                                decoration: InputDecoration(
                                  labelText: 'Card Limit',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) => provider.setCardBalance(
                                    double.parse(
                                        value.isNotEmpty ? value : '0')),
                                validator: (value) =>
                                    value!.isEmpty ? 'Enter Card Limit' : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: provider.cardHolderName,
                          decoration: InputDecoration(
                            labelText: 'Card Holder Name',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) =>
                              provider.setCardHolderName(value),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter card holder name' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: provider.cvv,
                          decoration: InputDecoration(
                            labelText: 'CVV',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          onChanged: (value) => provider.setCVV(value),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter CVV';
                            }
                            if (value.length != 3) {
                              return 'CVV must be 3 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () =>
                    {Navigator.pop(context),provider.clearFields()},
              ),
              ElevatedButton(
                  child: Text('Add Card'),
                  onPressed: () async {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            await _addCard(
                provider.cardNumber,
                provider.cardHolderName,
                provider.expiryDate,
                provider.cvv,
                provider.selectedBank,
                provider.cardBG.toString(),
                provider.cardBalance);

            Navigator.pop(context);
            provider.clearFields();
          }
                  }),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Cards',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _cards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No cards found. Add a new card.'));
          }
          final cards = snapshot.data!;
          return ListView.separated(
            separatorBuilder: (context, index) => SizedBox(
              height: 12,
            ),
            padding: EdgeInsets.all(16),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return ListTile(
                onTap: () => _showCardDetails(card, index),
                title: CreditCardUi(
                  // width: 50,

                  cardHolderFullName: card['card_holder_name']!,
                  cardNumber: card['card_number']!,
                  validThru: card['expiry_date']!,
                  cvvNumber: card['cvv'],
                  enableFlipping: true,
                  shouldMaskCardNumber: false,
                  showBalance: true,
                  balance: double.parse(card['card_balance'] ?? '0'),
                  topLeftColor: Colors.red,
                  currencySymbol: '₹',
                  autoHideBalance: true,
                  cardType: CardType.credit,
                  showValidFrom: false,
                  creditCardType: CreditCardType.none,
                  // creditCardType: CreditCardType.visa,
                  backgroundDecorationImage: int.parse(card['cardBG']?? '0') >0 ?DecorationImage(
                    // image: Image.network('https://cdn.pixabay.com/photo/2022/12/01/04/40/backpacker-7628303_1280.jpg').image,
                    image: Image.asset('assets/cardBG${card['cardBG']}.jpg').image,
                    fit: BoxFit.cover,
                  ):null,
                  cardProviderLogo: Image.network(
                    'https://raw.githubusercontent.com/Chirag4904/indian-banks/refs/heads/main/assets/logos/${bankMapping[card['bank']] ?? 'icic'}/logo.png', // Replace with the bank's logo URL
                    height: 10, // Adjust size if needed
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.grey[800], // Subtle dark color
        foregroundColor: Colors.white, // Icon and text color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Modern rectangular shape
        ),
        icon: Icon(Icons.add),
        label: Text(
          'Add Card',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        onPressed: _showAddCardDialog,
      ),
    );
  }
}
