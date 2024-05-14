import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DataFormPage extends StatefulWidget {
  const DataFormPage({super.key});

  @override
  DataFormPageState createState() => DataFormPageState();
}

class DataFormPageState extends State<DataFormPage> {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:3000';
  final _formKey = GlobalKey<FormState>();
  String _selectedValue = 'Charles de Gaulle';
  String? _link;
  String? _phoneNumber;
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  bool _isLoading = false;
  final List<String> _options = [
    'Charles de Gaulle',
    'Orly',
    'Paris',
  ];
  MessageMethod _selectedMethod = MessageMethod.sms; // Default to SMS
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _updateMessage();
    _loadHistory();
  }

  void _resetForm() {
    setState(() {
      _phoneNumber = null;
      _phoneNumberController.clear();
      _contactNameController.clear();
      _updateMessage();
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('history');
    if (historyJson != null) {
      List<dynamic> jsonDecoded = json.decode(historyJson);
      List<Map<String, String>> tempHistory = [];
      for (var entry in jsonDecoded) {
        DateTime dateTime;
        try {
          dateTime = DateTime.parse(entry["timestamp"]);
        } catch (e) {
          try {
            dateTime =
                DateFormat("dd/MM/yyyy 'à' HH:mm").parse(entry["timestamp"]);
          } catch (e) {
            print("Error parsing date for entry: ${entry["timestamp"]}");
            continue;
          }
        }
        tempHistory.add({
          "name": entry["name"] as String,
          "number": entry["number"] as String,
          "message": entry["message"] as String,
          "method": entry["method"] as String,
          "timestamp": DateFormat('dd/MM/yyyy à HH:mm').format(dateTime)
        });
      }
      setState(() {
        _history = tempHistory.reversed.toList();
      });
    }
  }

  void _addToHistory(
      String name, String number, String message, String method) async {
    final prefs = await SharedPreferences.getInstance();
    _history.add({
      "name": name.isEmpty ? 'Sans nom' : name,
      "number": number,
      "message": message,
      "method": method,
      "timestamp": DateTime.now().toIso8601String()
    });
    await prefs.setString('history', json.encode(_history));
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _messageController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (!_link!.startsWith("https://elifelimo.com/driver/?t=")) {
        _showErrorDialog(
            'Le seul site pris en charge pour le moment est "https://elifelimo.com/"');
        return;
      }
      setState(() {
        _isLoading = true;
      });
      try {
        var response =
            await http.get(Uri.parse('$baseUrl/api/get-data?pageUrl=$_link'));
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          setState(() {
            _phoneNumber = data['phoneNumber'];
            _phoneNumberController.text = _phoneNumber ?? '';
          });
        } else {
          _showErrorDialog('Échec de la récupération des données');
        }
      } catch (e) {
        _showErrorDialog('Erreur survenue : $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addToContacts() async {
    var permissionStatus = await Permission.contacts.status;
    if (!permissionStatus.isGranted) {
      await Permission.contacts.request();
      permissionStatus = await Permission.contacts.status;
    }

    if (permissionStatus.isGranted) {
      final phoneNumber = _phoneNumberController.text.trim();
      final contactName = _contactNameController.text.trim();

      if (phoneNumber.isNotEmpty && contactName.isNotEmpty) {
        final contact = Contact(
          givenName: contactName,
          phones: [Item(label: "mobile", value: phoneNumber)],
        );
        await ContactsService.addContact(contact);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$contactName a été ajouté à vos contacts')),
          );
        }
      } else {
        if (phoneNumber.isEmpty) {
          _showErrorDialog("Numéro de téléphone non disponible.");
        }
        if (contactName.isEmpty) {
          _showErrorDialog("Entrez un nom pour le nouveau contact");
        }
      }
    } else {
      _showErrorDialog(
          "L'application n'a pas été autorisée à accéder aux contacts");
    }
  }

  void _updateMessage() {
    String airport = _selectedValue;
    if (_selectedValue == 'Paris') {
      _messageController.text =
          "Good day! I'll be your chauffeur tomorrow, transporting you from your hotel to $airport Airport.\n\n"
          "Should you have any inquiries, don't hesitate to ask.\n\n"
          "Looking forward to seeing you in Paris! 😁";
    } else {
      _messageController.text =
          "Good day! I'll be your chauffeur tomorrow, transporting you from $airport Airport to your hotel.\n\n"
          "Could you kindly inform me if you'll be traveling with checked baggage or just carry-on items?\n\n"
          "Tomorrow, upon your arrival, please keep me informed of each step: landing, clearing customs, and waiting for your luggage.\n\n"
          "Should you have any inquiries, don't hesitate to ask.\n\n"
          "Looking forward to seeing you in Paris! 😁";
    }
  }

  void _sendMessage() async {
    final phoneNumber = _phoneNumberController.text.trim();
    final message =
        _messageController.text; // Use the message from the controller
    final method = _selectedMethod.toString() == "MessageMethod.whatsapp"
        ? "whatsapp"
        : "sms";

    if (phoneNumber.isEmpty) {
      _showErrorDialog("Numéro de téléphone non disponible.");
      return;
    }

    Uri url;
    if (_selectedMethod == MessageMethod.whatsapp) {
      url = Uri.parse(
          "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    } else {
      // Encode spaces as %20 for SMS URLs
      String encodedMessage =
          Uri.encodeComponent(message).replaceAll('+', '%20');
      url = Uri(
          scheme: 'sms',
          path: phoneNumber,
          queryParameters: {'body': encodedMessage});
    }

    if (await canLaunchUrl(url)) {
      _addToHistory(_contactNameController.text, _phoneNumberController.text,
          message, method);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog("Impossible de lancer l'application correspondante.");
    }
  }

  void _showHistoryDialog(Map<String, String> entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Détail des informations'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Nom: ${entry["name"]}'),
              const SizedBox(height: 10),
              Text('Numéro: ${entry["number"]}'),
              const SizedBox(height: 10),
              Text('Message: ${entry["message"]}'),
              const SizedBox(height: 10),
              Text('Envoyé par ${entry["method"]}'),
              const SizedBox(height: 10),
              Text('Date: ${entry["timestamp"]}'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Une erreur est survenue'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharme'),
        leading: _phoneNumber == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _resetForm,
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Text("Récupération des informations",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: const CircularProgressIndicator(
                        strokeWidth: 8,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_phoneNumber == null) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined),
                            const SizedBox(width: 10),
                            Text('Lieu de départ',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(), // to disable scrolling within the grid
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                3, // Adjust number of columns as needed
                            crossAxisSpacing:
                                10, // Horizontal space between cards
                            mainAxisSpacing: 10, // Vertical space between cards
                          ),
                          itemCount: _options.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedValue = _options[index];
                                  _updateMessage(); // Update the message when a card is selected
                                });
                              },
                              child: Card(
                                color: _selectedValue == _options[index]
                                    ? Colors.blue
                                    : Colors.white,
                                child: Center(
                                  child: Text(_options[index],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedValue == _options[index]
                                            ? Colors.white
                                            : Colors.black,
                                      )),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Entrez le lien',
                            prefixIcon: Icon(Icons.link),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8))),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.blue, width: 2.0),
                            ),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Veuillez entrer un lien'
                              : null,
                          onSaved: (value) => _link = value,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              )),
                            ),
                            onPressed: _fetchPhoneNumber,
                            child: const Text(
                              'Obtenir le numéro de téléphone',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        if (_history.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.history_outlined),
                              const SizedBox(width: 10),
                              Text('Historique',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        for (var entry in _history) ...[
                          InkWell(
                            onTap: () => _showHistoryDialog(entry),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry["name"]!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  Text(entry["number"]!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  Text(entry["timestamp"]!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.person_outlined),
                            const SizedBox(width: 10),
                            Text('Infos de contact',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _contactNameController,
                          decoration: const InputDecoration(
                              labelText: 'Nom du contact',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _phoneNumberController,
                          decoration: const InputDecoration(
                              labelText: 'Numéro de téléphone',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _addToContacts,
                            child: const Text('Ajouter à mes contacts'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.message_outlined),
                            const SizedBox(width: 10),
                            Text('Message',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                Radio(
                                  value: MessageMethod.sms,
                                  groupValue: _selectedMethod,
                                  onChanged: (MessageMethod? value) {
                                    setState(() {
                                      _selectedMethod = value!;
                                    });
                                  },
                                ),
                                const Text('SMS'),
                              ],
                            ),
                            Row(children: [
                              Radio(
                                value: MessageMethod.whatsapp,
                                groupValue: _selectedMethod,
                                onChanged: (MessageMethod? value) {
                                  setState(() {
                                    _selectedMethod = value!;
                                  });
                                },
                              ),
                              const Text('WhatsApp'),
                            ])
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          maxLines: 6,
                          controller: _messageController,
                          decoration: const InputDecoration(
                              labelText: 'Message personnalisé (optionnel)',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton(
                            onPressed: _sendMessage,
                            child: const Text('Envoyer le message'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

enum MessageMethod { whatsapp, sms }
