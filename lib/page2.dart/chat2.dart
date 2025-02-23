import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/chat2.dart';
import 'package:myproject/pages.dart/chatpage.dart';
import 'package:myproject/services/database.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/widget_support.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<Chat> {
  bool search = false;
  String? myName, myProfilePic, myUserName, myEmail, myRole;
  Stream<QuerySnapshot>? chatRoomsStream;
  getthesharedpref() async {
    myName = await SharedPreferenceHelper().getDisplayName();
    myProfilePic = await SharedPreferenceHelper().getUserPic();
    myUserName = await SharedPreferenceHelper().getUserName();
    myEmail = await SharedPreferenceHelper().getUserEmail();
    myRole = await SharedPreferenceHelper().getUserRole();
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    chatRoomsStream =
        await DatabaseMethods().getChatRooms(myUserName!, myRole!);
    setState(() {});
  }

  Widget ChatRoomList() {
    return StreamBuilder<QuerySnapshot>(
      stream: chatRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No Chat Rooms Found"));
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: snapshot.data!.docs.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = snapshot.data!.docs[index];
            return ChatRoomListTile(
              chatRoomId: ds.id,
              lastMessage: ds["lastMessage"],
              myUsername: myUserName!,
              timestamp: ds["lastMessageSendTs"],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    ontheload();
  }

  getChatRoomIdbyUsername(String a, String b) {
    if (a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)) {
      return "$b\_$a";
    } else {
      return "$a\_$b";
    }
  }

  var queryResultSet = [];
  var tempSearchStore = [];

  initiateSearch(value) {
    if (value.length == 0) {
      setState(() {
        queryResultSet = [];
        tempSearchStore = [];
      });
    }
    setState(() {
      search = true;
    });
    var capitalizedValue =
        value.substring(0, 1).toUpperCase() + value.substring(1);
    if (queryResultSet.isEmpty && value.length == 1) {
      DatabaseMethods().Search(value).then((QuerySnapshot docs) {
        for (int i = 0; i < docs.docs.length; ++i) {
          queryResultSet.add(docs.docs[i].data());
        }
      });
    } else {
      tempSearchStore = [];
      queryResultSet.forEach((element) {
        if (element['username'].startsWith(capitalizedValue)) {
          setState(() {
            tempSearchStore.add(element);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
            child: Column(children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                search
                    ? Expanded(
                        child: TextField(
                        onChanged: (value) {
                          initiateSearch(value.toUpperCase());
                        },
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search User',
                            hintStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.bold)),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w500),
                      ))
                    : Text(
                        'Chat',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold),
                      ),
                GestureDetector(
                  onTap: () {
                    search = true;
                    setState(() {});
                  },
                  child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: search
                          ? GestureDetector(
                              onTap: () {
                                search = false;
                                setState(() {});
                              },
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 25,
                              ),
                            )
                          : Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 25,
                            )),
                )
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            width: MediaQuery.of(context).size.width,
            height: search
                ? MediaQuery.of(context).size.height / 1.24
                : MediaQuery.of(context).size.height / 1.24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                search
                    ? ListView(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0),
                        primary: false,
                        shrinkWrap: true,
                        children: tempSearchStore.map((element) {
                          return buildResultCard(element);
                        }).toList())
                    : ChatRoomList(),
              ],
            ),
          ),
        ])));
  }

  Widget buildResultCard(data) {
    return GestureDetector(
      onTap: () async {
        search = false;
        setState(() {});

        // ตรวจสอบว่าไม่ใช่การแชทกับตัวเอง
        if (myUserName == data['username']) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot chat with yourself')));
          return;
        }

        try {
          // สร้าง chatRoomId
          var chatRoomId =
              getChatRoomIdbyUsername(myUserName!, data['username']);

          // สร้างข้อมูล chatRoom
          Map<String, dynamic> chatRoomInfoMap = {
            "users": [myUserName, data['username']],
            "roles": {myUserName: myRole, data['username']: data['role']},
            "time": FieldValue.serverTimestamp(),
            "lastMessage": "",
            "lastMessageSendTs": "",
            "sitterId":
                data['role'] == 'sitter' ? data['username'] : myUserName,
            "userId": data['role'] == 'user' ? data['username'] : myUserName,
          };

          // สร้างหรืออัพเดท chatRoom
          await DatabaseMethods().createChatRoom(chatRoomId, chatRoomInfoMap);

          // นำทางไปยังหน้าแชท
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                name: data['name'],
                profileurl: data['photo'],
                username: data['username'],
                role: data['role'],
              ),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error creating chat: $e')));
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: data['photo'] != null && data['photo'].isNotEmpty
                        ? Image.network(
                            data['photo'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person, color: Colors.grey);
                            },
                          )
                        : Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data["name"] ?? "Unknown",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        data['username'] ?? "",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: data['role'] == 'sitter'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (data['role'] ?? "").toUpperCase(),
                    style: TextStyle(
                      color: data['role'] == 'sitter'
                          ? Colors.blue[700]
                          : Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatRoomListTile extends StatefulWidget {
  final String chatRoomId;
  final String myUsername;
  final String lastMessage;
  final String timestamp;

  const ChatRoomListTile({
    Key? key,
    required this.chatRoomId,
    required this.myUsername,
    required this.lastMessage,
    required this.timestamp,
  }) : super(key: key);

  @override
  State<ChatRoomListTile> createState() => _ChatRoomListState();
}

class _ChatRoomListState extends State<ChatRoomListTile> {
  String profilePicUrl = "", name = "", username = "", role = "";

  getthisUserInfo() async {
    username =
        widget.chatRoomId.replaceAll("_", '').replaceAll(widget.myUsername, "");

    QuerySnapshot querySnapshot =
        await DatabaseMethods().getUserInfo(username.toUpperCase());
    if (querySnapshot.docs.isNotEmpty) {
      final userData = querySnapshot.docs[0].data() as Map<String, dynamic>;
      setState(() {
        name = userData['name'] ?? '';
        profilePicUrl = userData['photo'] ?? '';
        role = userData['role'] ?? '';
      });
    }
  }

  @override
  void initState() {
    getthisUserInfo();
    super.initState();
  }

  String getTimeDisplay(String timestamp) {
    // Add logic to format time display if needed
    return timestamp;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatPage(
                      name: name,
                      profileurl: profilePicUrl,
                      username: username,
                      role: role,
                    )));
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Picture
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: profilePicUrl.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        profilePicUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            SizedBox(width: 15),
            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Loading...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        getTimeDisplay(widget.timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (role.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'sitter'
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: role == 'sitter'
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ),
                    ],
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
