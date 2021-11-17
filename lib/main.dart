import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';

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
            return MultiProvider(
              providers: [
                  Provider<Auth>(
                    create: (_) => Auth(),
                  ),
                  StreamProvider(
                    create: (context) => context.read<Auth>().authStateChanges, initialData: null,
                  ),
              ],
              child: MyApp(),);
          }
          return Center(child: CircularProgressIndicator());
        },
    );
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Name Generator',
      theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          )
      ),
      home: RandomWords(),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  var _saved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  var _userImage;


  @override
  Widget build(BuildContext context) {
    var user = context.watch<User?>();
    var suggestionsList = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return const Divider();
          }
          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            onPressed: _pushSaved,
            icon: const Icon(Icons.star),
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            onPressed: (user != null)? _logout : _pushLogin,
            icon: (user != null)? const Icon(Icons.exit_to_app) : const Icon(Icons.login),
          ),
        ],
      ),
      body: (user == null)? suggestionsList : SnappingSheet(
        snappingPositions: [
          SnappingPosition.factor(
            positionFactor: 0.0,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(seconds: 1),
            grabbingContentOffset: GrabbingContentOffset.top,
          ),
          SnappingPosition.pixels(
            positionPixels: 170,
            snappingCurve: Curves.elasticOut,
            snappingDuration: Duration(milliseconds: 1750),
          ),
          SnappingPosition.factor(
            positionFactor: 1.0,
            snappingCurve: Curves.bounceOut,
            snappingDuration: Duration(seconds: 1),
            grabbingContentOffset: GrabbingContentOffset.bottom,
          ),
        ],
        // TODO: Add your content that is placed
        // behind the sheet. (Can be left empty)
        child: suggestionsList,
        grabbingHeight: 75,
        // TODO: Add your grabbing widget here,
        grabbing: Container(
          padding: const EdgeInsets.only(left: 15, bottom: 0, top: 0, right: 15),
          color: Colors.grey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'welcome back ${user.email}',
                style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white60
                ),
              ),
              Icon(Icons.arrow_drop_up, size: 50, color: Colors.white60,),

            ],
          ),
        ),
        sheetBelow: SnappingSheetContent(
          draggable: true,
          // TODO: Add your sheet content here
          child: Container(
              padding: const EdgeInsets.only(left: 15, bottom: 11, top: 25, right: 15),
              color: Colors.white,
              child: Wrap(children: [Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    child: FutureBuilder<void>(future: _getUserImage(user), builder: (context, snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.waiting: return Text('Loading....');
                        default:
                          if (snapshot.hasError)
                            return Text('Error: ${snapshot.error}');
                          else
                            return CircleAvatar(
                              backgroundImage: _userImage.image,
                              radius: 35,
                            );
                      }
                    }),
                    padding: const EdgeInsets.only(left: 5, bottom: 0, top: 0, right: 15),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.email}', style: const TextStyle(fontSize: 18),),
                      ElevatedButton(onPressed: () async {
                        await changeAvatar(context, user);
                        setState(() {

                        });
                      }, child: const Text('Change avatar'))
                    ],
                  )
                ],
              ),],
              )
          ),
        ),
      )
    );
  }

  Future<void> _getUserImage(User user) async {
    try{
      var url = await firebase_storage.FirebaseStorage.instance.ref().child('/${user.uid}').getDownloadURL();
      _userImage = Image.network(url);
    } catch (e) {
      var url = await firebase_storage.FirebaseStorage.instance.ref().child('/icon-256x256.png').getDownloadURL();
      _userImage = Image.network(url);
    }
  }

  void _pushLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => LogInPage(syncFavorites: syncFavorites,)));
  }

  void syncFavorites(Set<WordPair> cloudFavorites) {
    context.read<Auth>().syncFavorites(_saved);
    _saved = _saved.union(cloudFavorites);
  }

  void _logout() {
    context.read<Auth>().signOut();
  }


  void _pushSaved() {
    Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (context) {
              var loggedIn = (context.watch<User?>() == null) ? false : true;
              if(loggedIn) {
                //var cloudSaved =
              }
              final tiles = _saved.map(
                      (pair) {
                    return Dismissible(
                      key: ValueKey<String>(pair.toString()),
                      child: ListTile(
                          title: Text(
                            pair.asPascalCase,
                            style: _biggerFont,
                          )
                      ),
                      onDismissed: (dir) {
                        _saved.remove(pair);
                        context.read<Auth>().removePair(pair);
                        Navigator.of(context).build(context);
                      },
                      confirmDismiss: (dir) async {
                        return await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete Suggestion'),
                                content: Text('Are you sure you want to delete ${pair.toString()} from your saved suggestions?'),
                                actions: <Widget>[
                                  TextButton(
                                      style: TextButton.styleFrom(primary: Colors.deepPurple),
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Yes")
                                  ),
                                  TextButton(
                                      style: TextButton.styleFrom(primary: Colors.deepPurple),
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("No")
                                  ),
                                ],
                              );
                            }
                        );
                      },
                      background: Container(
                        child: Row(children: const [Icon(Icons.delete, color: Colors.white,), Text('Delete Suggestion', style: TextStyle(color: Colors.white, fontSize: 15),)],),
                        color: Colors.deepPurple,
                      ),
                    );
                  }
              ).toList();
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Saved Suggestions'),
                ),
                body: ListView.separated(
                  itemCount: tiles.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return tiles[index];
                  },
                ),
              );
            }
        )
    ).then((value) {
      setState(() {

      });
    });
  }

  Future<void> changeAvatar(BuildContext context, User user) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path as String);
      var storage = firebase_storage.FirebaseStorage.instance;
      storage.ref().child('/${user.uid}').putFile(file);
      await _getUserImage(user);
      setState(() {});
      await _getUserImage(user);
    } else {
      const snackBar = SnackBar(content: Text('No image selected'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
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
          if(alreadySaved) {
            _saved.remove(pair);
            context.read<Auth>().removePair(pair);
          } else {
            _saved.add(pair);
            context.read<Auth>().addPair(pair);
          }
        });
      },
    );
  }
}

typedef Set2VoidFunc = void Function(Set<WordPair>);

class LogInPage extends StatefulWidget {
  final Set2VoidFunc syncFavorites;
  const LogInPage({Key? key, required this.syncFavorites}) : super(key: key);

  @override
  _LogInPageState createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var _isLoginButtonDisabled = false;
  final _formKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    final email = Container(
      child: TextFormField(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
          hintText: 'Email',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        controller: emailController,
      ),
      margin: const EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
    );
    final password = Container(
      child: TextFormField(
        obscureText: true,
        decoration: const InputDecoration(
            contentPadding: EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
            hintText: 'Password',
            hintStyle: TextStyle(color: Colors.grey)
        ),
        controller: passwordController,
      ),
      margin: const EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
    );
    final welcomeText = Container(
      child: const Text('welcome to Startup Names Generator, please log in below', style: TextStyle(fontSize: 18)),
      margin: const EdgeInsets.only(left: 15, bottom: 25, top: 15, right: 15),
    );
    final logInButton = Container(
      child: ElevatedButton(
        onPressed: (_isLoginButtonDisabled)? null : _logIn,
        child: const Text('Log in'),
        style: ElevatedButton.styleFrom(
          primary: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
        ),
      ),
      margin: const EdgeInsets.only(left: 15, bottom: 0, top: 11, right: 15),
    );
    final signUpButton = Container(
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet<void>(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                    builder: (context, f) {
                      final confirmPassword = Container(
                        child: TextFormField(
                          key: _formKey,
                          validator: (val) {
                            if(val != passwordController.text)
                              return 'Passwords must match';
                            return null;
                          },
                          obscureText: true,
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
                              hintText: 'Password',
                              hintStyle: TextStyle(color: Colors.grey)
                          ),
                        ),
                        margin: const EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
                      );
                      final confirmButton = Container(
                        child: ElevatedButton(
                          onPressed: (_isLoginButtonDisabled)? null : _signUp,
                          child: const Text('Confirm'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                        margin: const EdgeInsets.only(left: 15, bottom: 0, top: 11, right: 15),
                      );
                      return Container(
                        padding: const EdgeInsets.only(left: 15, bottom: 11, top: 20, right: 15),
                        height: 200,
                        child: Column(
                          children: [
                            Text('Please confirm your password below:', style: TextStyle(fontSize: 15)),
                            confirmPassword,
                            confirmButton
                          ],
                        ),
                      );
                    }
                );
              }
          );
        },
        child: const Text('New user? Click to sign up'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
        ),
      ),
      margin: const EdgeInsets.only(left: 15, bottom: 11, top: 0, right: 15),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: ListView(children: [welcomeText, email, password, logInButton, signUpButton],),
    );
  }

  Future<void> _signUp() async {
      if(_formKey.currentState!.validate()){
        setState(() {
          _isLoginButtonDisabled = true;
        });
        await context.read<Auth>().signUp(email: emailController.text, password: passwordController.text);
        _logIn();
      }
  }

  void _logIn() async {
    setState(() {
      _isLoginButtonDisabled = true;
    });
    final bool _in = await context.read<Auth>().signIn(email: emailController.text, password: passwordController.text);
    var cloudFavorites = await context.read<Auth>().getCloudFavorites();
    setState(() {
      if(_in) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _isLoginButtonDisabled = false;
        emailController.clear();
        passwordController.clear();
        widget.syncFavorites(cloudFavorites);
      } else {
        const snackBar = SnackBar(content: Text('There was an error logging into the app'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        _isLoginButtonDisabled = false;
      }
    });
  }
}

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Auth();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<bool> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  void signOut() {
    _firebaseAuth.signOut();
  }

  Future<void> signUp({required String email, required String password}) async {
    _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    await signIn(email: email, password: password);
    _firestore.collection('users').doc(_firebaseAuth.currentUser!.uid).set({'favorites' : Map<String, dynamic>()});
    signOut();
  }

  void syncFavorites(Set<WordPair> set) {
    set.forEach((element) {
      addPair(element);
    });
  }

  void removePair(WordPair pair) {
    if(_firebaseAuth.currentUser == null) return;
    _firestore.collection("users").doc(_firebaseAuth.currentUser!.uid).collection("favorites")
        .doc(pair.toString()).delete();
  }

  void addPair(WordPair pair) {
    if(_firebaseAuth.currentUser == null) return;
     _firestore.collection("users").doc(_firebaseAuth.currentUser!.uid).collection("favorites")
        .doc(pair.toString()).set({'first': pair.first.toString(), 'second': pair.second.toString()});
  }

  Future<Set<WordPair>> getCloudFavorites() async {
    var set = Set<WordPair>();
    await _firestore.collection('users').doc(_firebaseAuth.currentUser!.uid).collection('favorites').get().then((res) {
      res.docs.forEach((element) {
        var first = element.data().entries.first.value.toString();
        var second = element.data().entries.last.value.toString();
        set.add(WordPair(first, second));
      });
    });
    return set;
  }
}
