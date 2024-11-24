import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  String? myName, myProfilePic, myUserName, myEmail;
  Stream? chatRoomsStream;

  getthesharedpref() async {
    myName = await SharedPreferenceHelper().getDisplayName();
    myProfilePic = await SharedPreferenceHelper().getUserPic();
    myUserName = await SharedPreferenceHelper().getUserName();
    myEmail = await SharedPreferenceHelper().getUserEmail();
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    chatRoomsStream = await DatabaseMethods().getChatRooms();
    setState(() {});
  }

  Widget ChatRoomList() {
    return StreamBuilder(
        stream: chatRoomsStream,
        builder: (context, AsyncSnapshot snapshot) {
          return snapshot.hasData
              ? ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: snapshot.data.docs.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    DocumentSnapshot ds = snapshot.data.docs[index];
                    print(ds.id);
                    return ChatRoomListTile(
                        chatRoomId: ds.id,
                        lastMessage: ds["lastMessage"],
                        myUsername: myUserName!,
                        time: ds["lastMessageSendTs"]);
                  })
              : Center(
                  child: CircularProgressIndicator(),
                );
        });
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
        var chatRoomId = getChatRoomIdbyUsername(myUserName!, data['username']);
        Map<String, dynamic> chatRoomInfoMap = {
          "users": [myUserName, data['username']]
        };
        await DatabaseMethods().createChatRoom(chatRoomId, chatRoomInfoMap);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatPage(
                      name: data['name'],
                      profileurl: data['photo'],
                      username: data['username'],
                    )));
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.network(
                    data['photo'],
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(
                  width: 15,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data["name"],
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(data['username'],
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ],
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
  final String lastMessage, chatRoomId, myUsername, time;
  ChatRoomListTile(
      {required this.chatRoomId,
      required this.lastMessage,
      required this.myUsername,
      required this.time});

  @override
  State<ChatRoomListTile> createState() => _ChatRoomListState();
}

class _ChatRoomListState extends State<ChatRoomListTile> {
  String profilePicUrl = "", name = "", username = "", id = "";
  getthisUserInfo() async {
    username =
        widget.chatRoomId.replaceAll("_", '').replaceAll(widget.myUsername, "");

    QuerySnapshot querySnapshot =
        await DatabaseMethods().getUserInfo(username.toUpperCase());
    name = '${querySnapshot.docs[0]['name']}';
    profilePicUrl = '${querySnapshot.docs[0]['photo']}';
    id = '${querySnapshot.docs[0]['email']}';
    setState(() {});
  }

  @override
  void initState() {
    getthisUserInfo();
    super.initState();
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
                    username: username)));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            profilePicUrl == ''
                ? CircularProgressIndicator()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      profilePicUrl,
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
            SizedBox(
              width: 20,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      username,
                      style: AppWidget.boldTextFeildStyle(),
                    ),
                  ],
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 3,
                  child: Text(
                    widget.lastMessage,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            Spacer(),
            Text(
              widget.time,
              style: TextStyle(
                  color: Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins'),
            ),
          ],
        ),
      ),
    );
  }
}
