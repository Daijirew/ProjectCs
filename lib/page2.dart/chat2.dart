import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myproject/page2.dart/chat2.dart';
import 'package:myproject/pages.dart/chatpage.dart';
import 'package:myproject/pages.dart/todayscreen.dart';
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
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

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
          return Center(
              child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  "ไม่พบการสนทนา",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "ค้นหาผู้รับเลี้ยงเพื่อเริ่มการสนทนา",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
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
    setState(() {
      _isSearching = true;
    });

    if (value.isEmpty) {
      setState(() {
        queryResultSet = [];
        tempSearchStore = [];
        _isSearching = false;
      });
      return;
    }

    // ลองทั้งแบบตัวพิมพ์ใหญ่ และตัวพิมพ์เล็ก
    DatabaseMethods().Search(value).then((QuerySnapshot docs) {
      if (docs.docs.isNotEmpty) {
        setState(() {
          queryResultSet = [];
          for (var doc in docs.docs) {
            queryResultSet.add(doc.data() as Map<String, dynamic>);
          }
          tempSearchStore = List.from(queryResultSet);
          _isSearching = false;
        });
      } else {
        // ลองดูว่าคอลเลกชันมีข้อมูลทั้งหมดกี่รายการ
        FirebaseFirestore.instance.collection("users").get().then((allDocs) {
          setState(() {
            _isSearching = false;
          });
        });
      }
    }).catchError((error) {
      print("เกิดข้อผิดพลาดในการค้นหา: $error");
      setState(() {
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ส่วนหัว
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (!search)
                    Text(
                      'การสนทนา',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  if (search)
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          initiateSearch(value);
                        },
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาผู้ใช้...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  Spacer(),

                  // เพิ่มปุ่มสำหรับไปที่หน้า Todayscreen
                  IconButton(
                    icon: Icon(
                      Icons.access_time, // ใช้ icon ที่เกี่ยวกับเวลา
                      color: Colors.orange,
                      size: 26,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Todayscreen(bookingId: '',)),
                      );
                    },
                    tooltip: 'ไปที่หน้าบันทึกเวลา',
                  ),

                  IconButton(
                    icon: Icon(
                      search ? Icons.close : Icons.search,
                      color: Colors.grey[700],
                      size: 26,
                    ),
                    onPressed: () {
                      setState(() {
                        search = !search;
                        if (!search) {
                          _searchController.clear();
                          queryResultSet = [];
                          tempSearchStore = [];
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // ส่วนที่เหลือคงเดิม...

            // ส่วนค้นหาและแสดงผล
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                ),
                child: search
                    ? _isSearching
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            children: tempSearchStore.isEmpty
                                ? [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 50),
                                        child: Column(
                                          children: [
                                            Icon(Icons.search_off,
                                                size: 64,
                                                color: Colors.grey[400]),
                                            SizedBox(height: 16),
                                            Text(
                                              'ไม่พบผู้ใช้',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ]
                                : tempSearchStore.map((element) {
                                    return buildResultCard(element);
                                  }).toList(),
                          )
                    : ChatRoomList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildResultCard(data) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          search = false;
          _searchController.clear();
        });

        // ตรวจสอบว่าไม่ใช่การแชทกับตัวเอง
        if (myUserName == data['username']) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ไม่สามารถสนทนากับตัวเองได้')));
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้างห้องสนทนา: $e')));
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.indigo.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: data['photo'] != null && data['photo'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          data['photo'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person,
                                color: Colors.orange[300], size: 32);
                          },
                        ),
                      )
                    : Icon(Icons.person, color: Colors.orange[300], size: 32),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data["name"] ?? "ไม่ระบุชื่อ",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      data['username'] ?? "",
                      style: TextStyle(
                        color: Colors.grey[600],
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
                  data['role'] == 'sitter' ? 'ผู้รับเลี้ยง' : 'ผู้ใช้งาน',
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
  bool _isLoading = true;

  getthisUserInfo() async {
    setState(() {
      _isLoading = true;
    });

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
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    getthisUserInfo();
    super.initState();
  }

  String getTimeDisplay(String timestamp) {
    if (timestamp.isEmpty) return '';

    // เพิ่มตรรกะการแสดงเวลาเพิ่มเติมถ้าต้องการ
    // เช่น แปลงเป็น "เมื่อวาน", "วันนี้", "5 นาทีที่แล้ว" เป็นต้น

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
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              _isLoading
                  ? Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: profilePicUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                profilePicUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person,
                                      color: Colors.indigo[300], size: 32);
                                },
                              ),
                            )
                          : Icon(Icons.person,
                              color: Colors.indigo[300], size: 32),
                    ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isLoading
                                ? 'กำลังโหลด...'
                                : (name.isNotEmpty ? name : 'ไม่ระบุชื่อ'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.timestamp.isNotEmpty)
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
                            widget.lastMessage.isEmpty
                                ? 'ยังไม่มีข้อความ'
                                : widget.lastMessage,
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: role == 'sitter'
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role == 'sitter' ? 'ผู้รับเลี้ยง' : 'ผู้ใช้งาน',
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
      ),
    );
  }
}
