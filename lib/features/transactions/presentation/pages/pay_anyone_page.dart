import 'package:firebase_auth/firebase_auth.dart'; // <--- Import Firebase Auth
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact_history_page.dart';
class PayAnyonePage extends StatefulWidget {
  final bool isSelectionMode;

  const PayAnyonePage({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<PayAnyonePage> createState() => _PayAnyonePageState();
}

class _PayAnyonePageState extends State<PayAnyonePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final List<Contact> _recentContacts = [];
  bool _permissionDenied = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndFetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _checkPermissionAndFetch() async {
    setState(() => _isLoading = true);
    var status = await Permission.contacts.status;
    if (status.isGranted) {
      _fetchContacts();
    } else {
      setState(() {
        _permissionDenied = status.isPermanentlyDenied || status.isDenied;
        _isLoading = false;
      });
    }
  }

  Future<void> _askPermission() async {
    var status = await Permission.contacts.request();
    if (status.isGranted) {
      _fetchContacts();
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  // --- UPDATED FETCH LOGIC ---
  Future<void> _fetchContacts() async {
    // 1. Get Logged In User's Number
    final user = FirebaseAuth.instance.currentUser;
    String? myNumberRaw = user?.phoneNumber;
    String myNumberClean = "";

    if (myNumberRaw != null) {
      // Clean your own number (remove +91, etc.) using same logic
      myNumberClean = _cleanAndFormat(myNumberRaw);
    }

    // 2. Fetch Contacts
    List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);

    var validContacts = contacts.where((c) {
      if (c.phones.isEmpty) return false;

      // Clean the contact's number
      String contactNumberRaw = c.phones.first.number;
      String contactNumberClean = _cleanAndFormat(contactNumberRaw);

      // --- FILTER 1: SELF CHECK ---
      // If the cleaned contact number matches MY cleaned number, hide it.
      if (myNumberClean.isNotEmpty && contactNumberClean == myNumberClean) {
        return false;
      }

      // --- FILTER 2: VALIDITY CHECK (Indian Mobile) ---
      bool isTenDigits = contactNumberClean.length == 10;
      bool startsWithValidDigit = ['6', '7', '8', '9'].contains(contactNumberClean.isNotEmpty ? contactNumberClean[0] : '');

      return isTenDigits && startsWithValidDigit;
    }).toList();

    if (mounted) {
      setState(() {
        _contacts = validContacts;
        _filteredContacts = validContacts;
        _permissionDenied = false;
        _isLoading = false;
      });
    }
  }

  // --- REUSABLE CLEANER FUNCTION ---
  // Returns exactly 10 digits for comparison
  String _cleanAndFormat(String raw) {
    String clean = raw.replaceAll(RegExp(r'\D'), ''); // Remove non-digits

    // Logic to strip country codes (91 or 0)
    if (clean.length == 12 && clean.startsWith('91')) {
      clean = clean.substring(2);
    } else if (clean.length == 11 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    return clean;
  }

  // Keep this for display search filtering
  String _cleanPhoneNumberSimple(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() => _filteredContacts = _contacts);
    } else {
      setState(() {
        _filteredContacts = _contacts.where((c) {
          String name = c.displayName.toLowerCase();
          String raw = c.phones.isNotEmpty ? c.phones.first.number : "";
          String clean = _cleanPhoneNumberSimple(raw);
          return name.contains(query.toLowerCase()) || clean.contains(query);
        }).toList();
      });
    }
  }

  void _onContactSelected(Contact contact) {
    // 1. Add to Local History
    if (!_recentContacts.contains(contact)) {
      setState(() {
        _recentContacts.insert(0, contact);
        if (_recentContacts.length > 5) _recentContacts.removeLast();
      });
    }

    // 2. CHECK MODE
    if (widget.isSelectionMode) {
      // MODE A: Add Money (Return Contact)
      Navigator.pop(context, contact);
    } else {
      // MODE B: Pay/Chat (Open History Page) <--- CHANGED
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContactHistoryPage(contact: contact),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _filterContacts,
          style: const TextStyle(fontSize: 18, color: Colors.black),
          decoration: InputDecoration(
            hintText: widget.isSelectionMode ? "Search contact" : "Pay anyone (Name or No.)",
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_permissionDenied || (_contacts.isEmpty && !_permissionDenied)) {
      return _buildPermissionRequestUI();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchController.text.isEmpty && _recentContacts.isNotEmpty) ...[
            const Text("Recent Searches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 15),
            ..._recentContacts.map((c) => _buildContactTile(c, isRecent: true)),
            const SizedBox(height: 30),
          ],
          if (_searchController.text.isEmpty) ...[
            const Text("All Contacts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 15),
          ],
          if (_filteredContacts.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text("No contacts found", style: TextStyle(color: Colors.grey))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) => _buildContactTile(_filteredContacts[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequestUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("Find your friends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Sync your contacts to pay them easily", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _askPermission,
            child: const Text("Allow Access"),
          )
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact, {bool isRecent = false}) {
    String name = contact.displayName;
    String phone = contact.phones.isNotEmpty ? contact.phones.first.number : "";
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    final List<Color> colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal];
    Color avatarColor = colors[name.length % colors.length];

    return GestureDetector(
      onTap: () => _onContactSelected(contact),
      child: Container(
        color: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor.withOpacity(0.8),
              child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}