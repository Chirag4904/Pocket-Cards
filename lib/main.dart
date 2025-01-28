import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pocket_cards/provider/card_provider.dart';
import 'package:provider/provider.dart';
import 'CreditCardScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CardProvider())
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Cards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF1B1E28),
        scaffoldBackgroundColor: Color(0xFF1B1E28),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1B1E28),
          elevation: 0,
        ),
      ),
      home: BiometricAuthScreen(),
    );
  }
}


class BiometricAuthScreen extends StatefulWidget {
  @override
  _BiometricAuthScreenState createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _authenticateUser();
  }

  Future<void> _authenticateUser() async {
    try {
      final bool isBiometricAvailable = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!isBiometricAvailable && !isDeviceSupported) {
        // If authentication is not available, proceed to the next screen without it.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreditCardScreen()),
        );
        return;
      }

      final bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access Pocket Cards',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow system PIN as well
        ),
      );

      if (authenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreditCardScreen()),
        );
      } else {
        _showErrorDialog('Authentication failed');
      }
    } catch (e) {
      // If there's an error, log it but proceed without authentication.
      debugPrint('Authentication error: ${e.toString()}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CreditCardScreen()),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Authentication'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticateUser(); // Allow retry
            },
            child: Text('Retry'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Authenticate')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Authenticate to Access Pocket Cards',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticateUser,
              child: Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }
}