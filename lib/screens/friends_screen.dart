// lib/screens/friends_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'friend_calendar_screen.dart';

class FriendsScreen extends StatefulWidget {
  final String currentUserEmail; 

  const FriendsScreen({super.key, required this.currentUserEmail});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // --- STATE FOR TABS 1 & 2 (LISTS) ---
  List<dynamic> _friends = [];
  List<dynamic> _pendingRequests = [];
  bool _isLoadingLists = false;

  // --- STATE FOR TAB 3 (SEARCH) ---
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = []; 
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchFriendships();
  }

  // --- 1. FETCH FRIENDSHIPS ---
  Future<void> _fetchFriendships() async {
    setState(() => _isLoadingLists = true);

    try {
      final response = await ApiService.getSecure('/friends/list');

      if (response.statusCode == 200) {
        final List<dynamic> allFriendships = jsonDecode(response.body);
        
        List<dynamic> tempFriends = [];
        List<dynamic> tempRequests = [];

        for (var f in allFriendships) {

          final status = (f['status'] as String).toUpperCase();
          
          if (status == 'ACCEPTED') {
            tempFriends.add(f);
          } else if (status == 'PENDING') {
            final bEmail = f['userB']['email'];
            final bUser = f['userB']['username'];
            if (bEmail == widget.currentUserEmail || bUser == widget.currentUserEmail) {
              tempRequests.add(f);
            }
          }
        }

        setState(() {
          _friends = tempFriends;
          _pendingRequests = tempRequests;
        });
      }
    } catch (e) {
      print("Error fetching friends: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLists = false);
    }
  }

  // --- 2. ACCEPT REQUEST ---
  Future<void> _acceptRequest(int friendshipId) async {
    try {
      final response = await ApiService.putSecure('/friends/accept/$friendshipId', {});

      if (response.statusCode == 200) {
        _fetchFriendships(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request accepted!'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Error accepting request: $e");
    }
  }

  // --- 3. SEARCH USER ---
  Future<void> _searchUser() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = []; 
    });

    try {
      final response = await ApiService.getSecure('/users/search?term=${_searchController.text.trim()}');

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
        
        if (_searchResults.isEmpty && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users found.'), backgroundColor: Colors.orange));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to search: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSearching = false);
    }
  }

// --- 4. SEND REQUEST ---
  Future<void> _sendFriendRequest(int targetUserId) async {
    try {
      final response = await ApiService.postSecure('/friends/request/$targetUserId', {});
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.green));
        setState(() {
           _searchResults.removeWhere((user) => user['id'] == targetUserId);
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Error sending request: $e");
    }
  }

  // Helper to determine the "Other" user in a friendship
  Map<String, dynamic> _getOtherUser(Map<String, dynamic> friendship) {
    final aEmail = friendship['userA']['email'];
    final aUser = friendship['userA']['username'];
    if (aEmail == widget.currentUserEmail || aUser == widget.currentUserEmail) {
      return friendship['userB'];
    }
    return friendship['userA'];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'My Friends'),
              Tab(icon: Icon(Icons.person_add), text: 'Requests'),
              Tab(icon: Icon(Icons.search), text: 'Find Users'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: MY FRIENDS ---
            _isLoadingLists 
              ? const Center(child: CircularProgressIndicator())
              : _friends.isEmpty
                ? const Center(child: Text('You have no friends yet. Go find some!'))
                : ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friendUser = _getOtherUser(_friends[index]);
                      return Card( // Wrapped in a Card to make it look clickable!
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friendUser['firstName'] ?? friendUser['username']),
                          subtitle: Text(friendUser['email']),
                          trailing: const Icon(Icons.calendar_month), // Visual cue!
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FriendCalendarScreen(
                                  friendName: friendUser['firstName'] ?? friendUser['username'],
                                  friendUsername: friendUser['username'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            
            // --- TAB 2: PENDING REQUESTS ---
            _isLoadingLists 
              ? const Center(child: CircularProgressIndicator())
              : _pendingRequests.isEmpty
                ? const Center(child: Text('No pending requests.'))
                : ListView.builder(
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      final sender = request['userA']; 
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(sender['firstName'] ?? sender['username']),
                        subtitle: Text(sender['email']),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptRequest(request['id']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Accept'),
                        ),
                      );
                    },
                  ),
            
            // --- TAB 3: SEARCH / ADD FRIENDS ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by exact email',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _searchUser),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _searchResults.isEmpty
                            ? const Center(child: Text('Search results will appear here.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                                                    
                                  // Don't show ourselves in the search results!
                                  if (user['email'] == widget.currentUserEmail || user['username'] == widget.currentUserEmail) {
                                    return const SizedBox.shrink(); 
                                  }

                                  return Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        child: const Icon(Icons.person, color: Colors.white),
                                      ),
                                      title: Text(
                                        user['firstName'] ?? user['username'] ?? 'User',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(user['email'] ?? ''),
                                      trailing: ElevatedButton.icon(
                                        onPressed: () => _sendFriendRequest(user['id']),
                                        icon: const Icon(Icons.person_add),
                                        label: const Text('Add'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}