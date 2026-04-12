import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/theme_service.dart';

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
        title: const Text('ADRESÁŘ'),
      ),
      body: Column(
        children: [
          ThemeService.amberStripe,
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                    ? _buildEmptyState()
                    : _buildContactList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        tooltip: 'Přidat kontakt',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Zatím žádné kontakty',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddContactDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('PŘIDAT KONTAKT'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: contact.isCopyRecipient
                  ? ThemeService.kRailSlate.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              child: Icon(
                contact.isCopyRecipient ? Icons.person_add : Icons.person,
                color: contact.isCopyRecipient
                    ? ThemeService.kRailSlate
                    : Theme.of(context).colorScheme.outline,
                size: 20,
              ),
            ),
            title: Text(contact.name,
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.email,
                    style: Theme.of(context).textTheme.bodySmall),
                if (contact.isCopyRecipient)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.copy_all,
                            size: 13, color: ThemeService.kRailSlate),
                        const SizedBox(width: 4),
                        Text(
                          'Příjemce v Kopie',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: ThemeService.kRailSlate,
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
                  icon: Icon(Icons.edit_outlined,
                      color: ThemeService.kRailSlate, size: 20),
                  tooltip: 'Upravit kontakt',
                ),
                IconButton(
                  onPressed: () => _showDeleteContactDialog(contact),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  tooltip: 'Smazat kontakt',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddContactDialog() {
    final nameController  = TextEditingController();
    final emailController = TextEditingController();
    bool isCopyRecipient  = false;

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
                decoration: const InputDecoration(labelText: 'Jméno'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Použít jako příjemce v kopii'),
                subtitle: const Text('Bude automaticky přidáván k příjemcům soupisu.'),
                value: isCopyRecipient,
                onChanged: (v) => setState(() => isCopyRecipient = v ?? false),
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
                final name  = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  await ContactService.createContact(name, email,
                      isCopyRecipient: isCopyRecipient);
                  _loadContacts();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('PŘIDAT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditContactDialog(Contact contact) {
    final nameController  = TextEditingController(text: contact.name);
    final emailController = TextEditingController(text: contact.email);
    bool isCopyRecipient  = contact.isCopyRecipient;

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
                decoration: const InputDecoration(labelText: 'Jméno'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Použít jako příjemce v Kopie'),
                subtitle: const Text('Bude automaticky přidáván k příjemcům soupisu.'),
                value: isCopyRecipient,
                onChanged: (v) => setState(() => isCopyRecipient = v ?? false),
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
                final name  = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isNotEmpty && email.isNotEmpty) {
                  await ContactService.updateContact(contact.id, name, email,
                      isCopyRecipient: isCopyRecipient);
                  _loadContacts();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('ULOŽIT'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ContactService.deleteContact(contact.id);
              _loadContacts();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('SMAZAT'),
          ),
        ],
      ),
    );
  }
}
