import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await ContactService.getAllContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adresář'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF091620)
            : const Color(0xFF591664),
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.contacts_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Zatím žádné kontakty',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAddContactDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Přidat kontakt'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: contact.isCopyRecipient
                              ? const Icon(Icons.person_add, color: Colors.blue)
                              : const Icon(Icons.person),
                        ),
                        title: Text(contact.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.email),
                            if (contact.isCopyRecipient)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_all,
                                        size: 14, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Příjemce v Kopie',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showEditContactDialog(contact),
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 20),
                              tooltip: 'Upravit kontakt',
                            ),
                            IconButton(
                              onPressed: () =>
                                  _showDeleteContactDialog(contact),
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              tooltip: 'Smazat kontakt',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        tooltip: 'Přidat kontakt',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    bool isCopyRecipient = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Přidat kontakt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Použít jako příjemce v kopii'),
                subtitle: const Text(
                    'Bude automaticky přidáván k příjemcům soupisu.'),
                value: isCopyRecipient,
                onChanged: (bool? value) {
                  setState(() {
                    isCopyRecipient = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();

                if (name.isNotEmpty && email.isNotEmpty) {
                  await ContactService.createContact(name, email,
                      isCopyRecipient: isCopyRecipient);
                  _loadContacts();
                  Navigator.pop(context);
                }
              },
              child: const Text('Přidat'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditContactDialog(Contact contact) {
    final nameController = TextEditingController(text: contact.name);
    final emailController = TextEditingController(text: contact.email);
    bool isCopyRecipient = contact.isCopyRecipient;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Upravit kontakt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Použít jako příjemce v Kopie'),
                subtitle: const Text(
                    'Bude automaticky přidáván k příjemcům soupisu.'),
                value: isCopyRecipient,
                onChanged: (bool? value) {
                  setState(() {
                    isCopyRecipient = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();

                if (name.isNotEmpty && email.isNotEmpty) {
                  await ContactService.updateContact(contact.id, name, email,
                      isCopyRecipient: isCopyRecipient);
                  _loadContacts();
                  Navigator.pop(context);
                }
              },
              child: const Text('Uložit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteContactDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat kontakt'),
        content: Text('Opravdu chcete smazat kontakt "${contact.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ContactService.deleteContact(contact.id);
              _loadContacts();
              Navigator.pop(context);
            },
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
  }
}
