import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class DataFormPage extends StatefulWidget {
  const DataFormPage({super.key});

  @override
  DataFormPageState createState() => DataFormPageState();
}

class DataFormPageState extends State<DataFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedValue = 'Charles de Gaulle';
  String? _link;
  String? _phoneNumber;
  final String _customMessage = 'Ceci est le message envoyé par défaut.';
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  final List<String> _options = [
    'Charles de Gaulle',
    'Orly',
    'Beauvais',
    'Option 4'
  ];
  MessageMethod _selectedMethod = MessageMethod.whatsapp; // Default to WhatsApp

  @override
  void initState() {
    super.initState();
    _messageController.text = _customMessage;
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      try {
        var response = await http
            .get(Uri.parse('http://10.0.2.2:3000/api/get-data?pageUrl=$_link'));
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

  void _sendMessage() async {
    final phoneNumber = _phoneNumberController.text.trim();
    final message = Uri.encodeComponent(_messageController.text);

    if (phoneNumber.isEmpty) {
      _showErrorDialog("Numéro de téléphone non disponible.");
      return;
    }

    Uri url;
    if (_selectedMethod == MessageMethod.whatsapp) {
      url = Uri.parse("https://wa.me/$phoneNumber?text=$message");
    } else {
      // Handle SMS
      url = Uri(
          scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorDialog("Impossible de lancer l'application correspondante.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erreur'),
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
      appBar: AppBar(title: const Text('Sharme')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_phoneNumber == null) ...[
                        Text('Choisir une destination',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedValue,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0))),
                          onChanged: (value) =>
                              setState(() => _selectedValue = value!),
                          validator: (value) =>
                              value == null ? 'Champ obligatoire' : null,
                          items: _options
                              .map((value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'URL', border: OutlineInputBorder()),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Veuillez entrer un lien'
                              : null,
                          onSaved: (value) => _link = value,
                        ),
                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton(
                            onPressed: _fetchPhoneNumber,
                            child: const Text('Obtenir le numéro de téléphone'),
                          ),
                        ),
                      ] else ...[
                        ListTile(
                          title: const Text('WhatsApp'),
                          leading: Radio(
                            value: MessageMethod.whatsapp,
                            groupValue: _selectedMethod,
                            onChanged: (MessageMethod? value) {
                              setState(() {
                                _selectedMethod = value!;
                              });
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('SMS'),
                          leading: Radio(
                            value: MessageMethod.sms,
                            groupValue: _selectedMethod,
                            onChanged: (MessageMethod? value) {
                              setState(() {
                                _selectedMethod = value!;
                              });
                            },
                          ),
                        ),
                        TextFormField(
                          controller: _phoneNumberController,
                          decoration: const InputDecoration(
                              labelText: 'Numéro de téléphone',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          maxLines: 4,
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
