import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Repositories',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RepositoryList(),
    );
  }
}

class Repository {
  final String name;
  final String fullName;

  Repository({required this.name, required this.fullName});

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      name: json['name'],
      fullName: json['full_name'],
    );
  }
}

class Commit {
  final String message;
  final String date;

  Commit({required this.message, required this.date});

  factory Commit.fromJson(Map<String, dynamic> json) {
    return Commit(
      message: json['commit']['message'],
      date: json['commit']['author']['date'],
    );
  }
}

Future<List<Repository>> fetchRepositories() async {
  final String token = dotenv.env['GITHUB_TOKEN']!;
  final response = await http.get(
    Uri.parse('https://api.github.com/users/freeCodeCamp/repos'),
    headers: {
      'Authorization': 'token $token',
    },
  );

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    return data.map((repo) => Repository.fromJson(repo)).toList();
  } else {
    throw Exception('Failed to load repositories: ${response.reasonPhrase}');
  }
}

Future<Commit> fetchLastCommit(String repoFullName) async {
  final String token = dotenv.env['GITHUB_TOKEN']!;
  final response = await http.get(
    Uri.parse('https://api.github.com/repos/$repoFullName/commits'),
    headers: {
      'Authorization': 'token $token',
    },
  );

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    return Commit.fromJson(data.first);
  } else {
    throw Exception('Failed to load commit: ${response.reasonPhrase}');
  }
}

class RepositoryList extends StatefulWidget {
  @override
  _RepositoryListState createState() => _RepositoryListState();
}

class _RepositoryListState extends State<RepositoryList> {
  late Future<List<Repository>> futureRepositories;

  @override
  void initState() {
    super.initState();
    futureRepositories = fetchRepositories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GitHub Repositories')),
      body: FutureBuilder<List<Repository>>(
        future: futureRepositories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No Repositories Found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return FutureBuilder<Commit>(
                  future: fetchLastCommit(snapshot.data![index].fullName),
                  builder: (context, commitSnapshot) {
                    if (commitSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text(snapshot.data![index].name),
                        subtitle: Text('Loading last commit...'),
                      );
                    } else if (commitSnapshot.hasError) {
                      return ListTile(
                        title: Text(snapshot.data![index].name),
                        subtitle: Text('Error loading commit'),
                      );
                    } else {
                      return ListTile(
                        title: Text(snapshot.data![index].name),
                        subtitle: Text('Last commit: ${commitSnapshot.data!.message}'),
                      );
                    }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
