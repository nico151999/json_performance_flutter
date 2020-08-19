import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final String _title = 'JSON Test';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: _title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<String> _files;
  bool _running;
  Map<String, String> _fileStrings;
  Map<String, List<Tuple2<int, int>>> _fileResults;

  @override
  void initState() {
    super.initState();
    _files = List<String>();
    _running = false;
    _fileResults = Map<String, List<Tuple2<int, int>>>();
    _readAssets();
  }

  Future<void> _readAssets() async {
    AssetBundle bundle = DefaultAssetBundle.of(context);
    Map<String, dynamic> manifestMap = jsonDecode(
        await bundle.loadString('AssetManifest.json')
    );
    _files = manifestMap.keys.toList();

    _fileStrings = Map<String, String>();
    for (String file in _files) {
      _fileStrings[file] = await bundle.loadString(file, cache: false);
    }
  }

  void _runPerformanceTest() async {
    setState(() {
      _fileResults.clear();
      _running = true;
    });
    Map<String, List<Tuple2<int, int>>> result = await compute(
        testPerformance,
        _fileStrings
    );
    setState(() {
      _fileResults = result;
      _running = false;
    });
  }

  String _getAverages(List<Tuple2<int, int>> measurements) {
    int encodingSum = 0;
    int decodingSum = 0;
    measurements.forEach((measurement) {
      encodingSum += measurement.item1;
      decodingSum += measurement.item2;
    });
    int itemCount = measurements.length;
    return 'Parsing: ${encodingSum/itemCount}µs\nCreation: ${decodingSum/itemCount}µs';
  }

  List<Text> _getAverageVisualization() {
    List<Text> ret = List<Text>();
    for (String file in _files) {
      ret.add(Text('$file file average:'));
      String value;
      if (_fileResults.isEmpty) {
        value = 'Waiting...';
      } else {
        value = _getAverages(_fileResults[file]);
      }
      ret.add(Text(
        value,
        style: Theme.of(context).textTheme.headline6,
      ));
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _getAverageVisualization(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _running ? null : _runPerformanceTest,
        tooltip: 'Start performance test',
        child: _running ? Icon(Icons.data_usage) : Icon(Icons.play_arrow),
        backgroundColor: _running ? Colors.red : null,
      ),
    );
  }
}

Future<Map<String, List<Tuple2<int, int>>>> testPerformance(Map<String, String> param) async {
  Map<String, List<Tuple2<int, int>>> ret = Map<String, List<Tuple2<int, int>>>();
  param.keys.forEach((file) {
    ret[file] = List<Tuple2<int, int>>();
  });

  int iterations = 10;
  Map<String, dynamic> parsed;
  String jsonString;
  for (int i = 0; i < iterations; i++) {
    for (String file in param.keys) {
      jsonString = param[file];
      int startTimestamp = DateTime
          .now()
          .microsecondsSinceEpoch;
      parsed = jsonDecode(jsonString);
      int parsedTimestamp = DateTime
          .now()
          .microsecondsSinceEpoch;
      jsonEncode(parsed);
      int endTimestamp = DateTime
          .now()
          .microsecondsSinceEpoch;
      int parsingTime = parsedTimestamp - startTimestamp;
      int creationTime = endTimestamp - parsedTimestamp;
      print("Parsing $file took $parsingTimeµs");
      print("Creating $file took $creationTimeµs");
      ret[file].add(Tuple2<int, int>(parsingTime, creationTime));
    }
  }

  return ret;
}