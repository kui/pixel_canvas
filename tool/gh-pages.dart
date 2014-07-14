#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';

import 'package:ghpages_generator/ghpages_generator.dart' as gh;
import 'package:path/path.dart' as path;

String PROJECT_DIR =
    path.absolute(
        path.dirname(
            path.dirname(Platform.script.toFilePath())));
String EXAMPLE_DIR = path.join(PROJECT_DIR, 'example');

main() {
  var ghGen = new gh.Generator(rootDir: PROJECT_DIR)
    ..withExamples = true;

  ghGen.generate(doCustomTask: (workDir) {
    gh.moveExampleAtRoot(workDir);
    return new IndexGenerator.fromPath(workDir).generate();
  });
}

class IndexGenerator {
  List<File> indexes;
  final Directory baseDir;

  String fileName = 'index.html';
  bool overwrite = false;
  bool recursive = true;
  List<String> excludes = ['packages', '.git'];

  IndexGenerator(this.baseDir);
  IndexGenerator.fromPath(String path): this(new Directory(path));

  /**
   * Generate index files which named [fileName]
   * Return a future of generated files
   */
  Future<List<File>> generate() {
    var dirs = recursive ? _dirs : new Stream.fromIterable([baseDir]);
    return _generate(dirs);
  }

  /**
   * Delete index files.
   * Return a future of deleted (generated) files.
   */
  Future<List<File>> delete() {
    var deleteds = indexes.map((f) {
      print('Delete index page: ${f.path}');
      return f.delete();
    });
    return Future.wait(deleteds);
  }

  Future<List<File>> _generate(Stream<Directory> dirs) {
    Stream<File> targetIndexes = dirs
        .map((d) => path.join(d.path, fileName))
        .map((String i) => new File(i));

    if (!overwrite) {
      targetIndexes =
        targetIndexes.asyncExpand((File i) => _removeIfExests(i));
    }

    return targetIndexes
        .asyncExpand((f) => _generateIndex(f).asStream())
        .toList()
        .then((i) {indexes = i; return indexes;});
  }

  Future<File> _generateIndex(File idx) {
    print('Create index page: ${idx.path}');

    var p = (idx.parent.path == baseDir.path) ?
        '/' : path.relative(idx.parent.path, from: baseDir.path);
    var title = 'Index of $p';

    var filesFuture = idx.parent.list()
        .map((e) => path.basename(e.path))
        .where((name) => name != path.basename(idx.path))
        .where((String name) => name.endsWith('.html'))
        .toList();
    var outputFuture = idx.open(mode: FileMode.WRITE);

    return Future.wait([filesFuture, outputFuture])
        .then((List args) {
          List<String> files = args[0];
          RandomAccessFile output = args[1];
          String content = _buildIndexHtml(title, files);
          return output.writeString(content);
        })
        .then((_) => idx);
  }

  String _buildIndexHtml(String title, List files) {
    var content = new StringBuffer()
      ..writeln('<meta charset="utf-8">')
      ..writeln('<title>$title</title>')
      ..writeln('<h1>$title</h1>');
    if (files.isEmpty) {
      content.writeln('<p>No content</p>');
    } else {
      content
          ..writeln('<ul>')
          ..writeln(files
              .map((f) => '<li><a href="$f">$f</a></li>')
              .join('\n'))
          ..write('</ul>');
    }
    return content.toString();
  }

  Stream<Directory> get _dirs {
    var subs = baseDir.list(recursive: true)
      .where((e) => e is Directory)
      .where((Directory d) => !_isInExcludes(d.path));
    var base = new Stream.fromIterable([baseDir]);

    return _mergeStream([base, subs]);
  }

  bool _isInExcludes(String p) {
    var relPath = path.split(path.relative(p, from: baseDir.path));
    return excludes.any((e) => relPath.contains(e));
  }

  Stream _mergeStream(Iterable<Stream> streams) {
    int openStreams = streams.length;
    StreamController c = new StreamController();
    streams.forEach((s) {
      s.listen(c.add)
        ..onError(c.addError)
        ..onDone((){
          openStreams--;
          if (openStreams == 0) c.close();
        });
    });
    return c.stream;
  }

  Stream<File> _removeIfNotExests(File file) =>
      _removeIf(file.exists(), file);

  Stream<File> _removeIfExests(File file) =>
      _removeIf(file.exists().then((b)=> !b), file);

  Stream _removeIf(Future<bool> condition, element) =>
      condition
        .then((e) => (e) ? element : null)
        .asStream()
        .where((i) => i != null);
}
