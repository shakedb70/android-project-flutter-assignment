import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:hello_me/auth_repository.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  //home screen
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => FirebaseRepository.instance(),
        child: MaterialApp(
          title: 'Startup Name Generator',
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          home: RandomWords(),
        ));
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  bool _IsUp = false;
  final SnappingSheetController _userController = SnappingSheetController();

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseRepository>(
        builder: (context, auth, _) => StreamBuilder<QuerySnapshot?>(
            stream: FirebaseRepository.instance().getFavoritesFromDatabase(),
            builder: (BuildContext context,
                AsyncSnapshot<QuerySnapshot?>? snapshot) {
              if (snapshot!.data != null &&
                  (snapshot.connectionState == ConnectionState.done ||
                      snapshot.connectionState == ConnectionState.active) &&
                  snapshot.data != null &&
                  snapshot.data!.docs.isNotEmpty) {
                Map<String, dynamic>? data =
                    snapshot.data!.docs[0].data() as Map<String, dynamic>;
                for (String favorite in data["favorites"].toList()) {
                  auth.addToFavorites(favorite);
                }
              }

              IconButton loginButton;
              SnappingSheet user = SnappingSheet();

              if (!auth.isAuthenticated) {
                loginButton = IconButton(
                  icon: const Icon(Icons.login),
                  onPressed: _pushLogin,
                  tooltip: 'Login',
                );
              } else {
                loginButton = IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: _pushExit,
                  tooltip: 'Logout',
                );
                user = SnappingSheet(
                  controller: _userController,
                  lockOverflowDrag: true,
                  snappingPositions: const [
                    SnappingPosition.factor(
                      positionFactor: 0.0,
                      snappingCurve: Curves.easeOutExpo,
                      snappingDuration: Duration(seconds: 1),
                      grabbingContentOffset: GrabbingContentOffset.top,
                    ),
                    SnappingPosition.factor(
                      positionFactor: 0.3,
                      snappingCurve: Curves.elasticOut,
                      snappingDuration: Duration(seconds: 1750),
                    ),
                    SnappingPosition.factor(
                      positionFactor: 0.7,
                      snappingCurve: Curves.bounceOut,
                      snappingDuration: Duration(seconds: 1),
                      grabbingContentOffset: GrabbingContentOffset.bottom,
                    ),
                  ],
                  child: _buildSuggestions(),
                  grabbingHeight: 50,
                  grabbing: GestureDetector(
                    onTap: () {
                      setState(() {
                        _IsUp = !_IsUp;

                        if (_IsUp) {
                          _userController.snapToPosition(
                              const SnappingPosition.factor(
                                  positionFactor: 0.15));
                        } else {
                          _userController.snapToPosition(
                              const SnappingPosition.factor(
                                  positionFactor: 0.03));
                        }
                      });
                    },
                    child: _IsUp
                        ? Container(
                            color: Colors.grey,
                            child: Row(
                              children: [
                                Text(
                                  "Welcome back, " + auth.user!.email!,
                                  style: _biggerFont,
                                ),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down),
                              ],
                            ),
                          )
                        : Container(
                            color: Colors.grey,
                            child: Row(
                              children: [
                                Text("Welcome back, " + auth.user!.email!,
                                    style: _biggerFont),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_up),
                              ],
                            ),
                          ),
                  ),
                  sheetAbove: null,
                  sheetBelow: SnappingSheetContent(
                      draggable: true,
                      child: Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                              child: Column(children: [
                            ListTile(
                              title:
                                  Text(auth.user!.email!, style: _biggerFont),
                              subtitle: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                        onPressed: () async {
                                          FilePickerResult? result =
                                              await FilePicker.platform
                                                  .pickFiles(type: FileType.image);

                                          if (result != null) {
                                            File file =
                                                File(result.files.single.path!);
                                            String fileName = auth.user!.email!;

                                            // Upload file
                                            String url = await FirebaseStorage
                                                .instance
                                                .ref('avatar/$fileName')
                                                .putFile(file)
                                                .then((snapshot) => snapshot.ref
                                                    .getDownloadURL());

                                            setState(() {
                                              auth.setImage(url);
                                            });
                                          }
                                        },
                                        child: const Text(
                                          "Change avatar",
                                        )),
                                  ]),
                              leading: auth.image == ""
                                  ? const Icon(Icons.highlight_off)
                                  : CircleAvatar(
                                      backgroundImage: NetworkImage(auth.image),
                                      backgroundColor: Colors.transparent,
                                    ),
                            ),
                          ])))),
                );
              }

              return Scaffold(
                appBar: AppBar(
                  title: const Text('Startup Name Generator'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.star),
                      onPressed: _pushSaved,
                      tooltip: 'Saved Suggestions',
                    ),
                    loginButton
                  ],
                ),
                body: auth.isAuthenticated ? user : _buildSuggestions(),
              );
            }));
  }

  void _pushExit() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Successfully logged out")));

    setState(() {
      Provider.of<FirebaseRepository>(context, listen: false).signOut();
    });
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final tiles = Provider.of<FirebaseRepository>(context, listen: false)
              .favorites
              .map(
            (pair) {
              return Dismissible(
                child: ListTile(
                  title: Text(
                    pair,
                    style: _biggerFont,
                  ),
                ),
                key: ValueKey<String>(pair),
                background: Container(
                  color: Colors.deepPurple,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        WidgetSpan(
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                            text: 'Delete Suggestion',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                confirmDismiss: (DismissDirection direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Delete Suggestion"),
                        content: Text("Are you sure you want to delete"
                            " $pair from your saved suggestions?"),
                        actions: <Widget>[
                          ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Yes")),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("No"),
                          ),
                        ],
                      );
                    },
                  );
                  return false;
                },
                onDismissed: (DismissDirection direction) {
                  setState(() {
                    Provider.of<FirebaseRepository>(context, listen: false)
                        .deleteFromFavorites(pair);
                  });
                },
              );
            },
          );
          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void _pushLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
            ),
            body: LoginPage(),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return Divider();
          }

          final int index = i ~/ 2;

          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = Provider.of<FirebaseRepository>(context, listen: false)
        .favorites
        .contains(pair.asPascalCase);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.star : Icons.star_border,
        color: alreadySaved ? Colors.deepPurple : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () {
        setState(() {
          if (alreadySaved) {
            setState(() {
              Provider.of<FirebaseRepository>(context, listen: false)
                  .deleteFromFavorites(pair.asPascalCase);
            });
          } else {
            setState(() {
              Provider.of<FirebaseRepository>(context, listen: false)
                  .addToFavorites(pair.asPascalCase);
            });
          }
        });
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            body: Column(
            children: [
              const Text(
                  "Welcome to Startup Names Generator, please log in below"),
              TextField(
                  obscureText: false,
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  )),
              TextField(
                  obscureText: true,
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  )),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: const Text("Log In"),
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.deepPurple),
                        foregroundColor:
                            MaterialStateProperty.all<Color>(Colors.white),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(18.0)))),
                    onPressed: () async {
                      setState(() {
                        loading = true;
                      });
                      if (!(await Provider.of<FirebaseRepository>(context,
                              listen: false)
                          .signIn(
                              emailController.text, passwordController.text))) {
                        if (!Provider.of<FirebaseRepository>(context,
                                listen: false)
                            .isAuthenticated) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "There was an error logging into the app")));
                        } else {
                          setState(() {
                            Navigator.pop(context);
                          });
                        }
                      } else {
                        setState(() {
                          Navigator.pop(context);
                        });
                      }
                      setState(() {
                        loading = false;
                      });
                    },
                  )),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: const Text("New user? Click to sign up"),
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.blue),
                        foregroundColor:
                            MaterialStateProperty.all<Color>(Colors.white),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(18.0)))),
                    onPressed: () async {
                      showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return Container(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                    "Please confirm your password below:"),
                                TextField(
                                    obscureText: true,
                                    controller: confirmController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    )),
                                ElevatedButton(
                                  child: const Text("Confirm"),
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            Colors.blue),
                                    foregroundColor:
                                        MaterialStateProperty.all<Color>(
                                            Colors.white),
                                  ),
                                  onPressed: () async {
                                    if (passwordController.text !=
                                        confirmController.text) {
                                      setState(() {
                                        Navigator.pop(context);
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Passwords must match")));
                                    } else {
                                      await Provider.of<FirebaseRepository>(
                                              context,
                                              listen: false)
                                          .signUp(emailController.text,
                                              passwordController.text);
                                      setState(() {
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      });
                                    }
                                  },
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom),
                                )
                              ],
                            ));
                          });
                    },
                  ))
            ],
          ));
  }
}
