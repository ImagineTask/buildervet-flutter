import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

/// A specialized service for handling application logs with multi-level files, 
/// date-based naming, and size-based rotation/cleanup.
class Log {
  static Logger? _logger;
  static Directory? _logDir;
  static const int _maxFileSize = 100 * 1024 * 1024; // 100 MB
  static const int _maxTotalSize = 300 * 1024 * 1024; // 300 MB
  static const int _maxLogAgeDays = 7;

  /// Initializes the logging system.
  static Future<void> init() async {
    try {
      if (kIsWeb) {
        _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            printTime: true,
          ),
          output: ConsoleOutput(),
        );
        i('Logging initialized (Web Mode: Console only)');
        return;
      }

      final supportDir = await getApplicationSupportDirectory();
      _logDir = Directory(p.join(supportDir.path, 'logs'));
      
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }

      // Initial cleanup
      await _cleanupLogs();

      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0, 
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          _MultiLevelFileOutput(_logDir!),
        ]),
      );

      i('Logging initialized. Log folder: ${_logDir!.path}');
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  static Future<void> _cleanupLogs() async {
    if (_logDir == null) return;
    final now = DateTime.now();
    try {
      List<File> allFiles = [];
      int totalSize = 0;

      // 1. Age-based cleanup (7 days)
      if (await _logDir!.exists()) {
        final entities = _logDir!.listSync();
        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.log')) {
            final lastModified = await entity.lastModified();
            if (now.difference(lastModified).inDays >= _maxLogAgeDays) {
              await entity.delete();
            } else {
              allFiles.add(entity);
              totalSize += await entity.length();
            }
          }
        }
      }

      // 2. Total size-based cleanup (300 MB)
      if (totalSize > _maxTotalSize) {
        // Sort by last modified time, oldest first
        allFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        
        for (var file in allFiles) {
          if (totalSize <= _maxTotalSize) break;
          int fileSize = await file.length();
          await file.delete();
          totalSize -= fileSize;
        }
      }
    } catch (e) {
      print('Error cleaning up logs: $e');
    }
  }

  static void i(String message) => _logger?.i(message);
  static void w(String message) => _logger?.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) => 
      _logger?.e(message, error: error, stackTrace: stackTrace);
  static void d(String message) => _logger?.d(message);
}

class _MultiLevelFileOutput extends LogOutput {
  final Directory logDir;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  _MultiLevelFileOutput(this.logDir);

  @override
  void output(OutputEvent event) {
    try {
      final dateStr = _dateFormat.format(DateTime.now());
      String levelPrefix = 'info';
      
      switch (event.level) {
        case Level.warning:
          levelPrefix = 'warn';
          break;
        case Level.error:
        case Level.fatal:
          levelPrefix = 'error';
          break;
        default:
          levelPrefix = 'info';
      }

      final fileName = '${levelPrefix}_$dateStr.log';
      final file = File(p.join(logDir.path, fileName));
      
      // Check individual file size limit (100MB)
      if (file.existsSync() && file.lengthSync() > Log._maxFileSize) {
        // Simple rotation within the same day if needed
        final rotFile = File(p.join(logDir.path, '${levelPrefix}_${dateStr}_${DateTime.now().millisecondsSinceEpoch}.log'));
        file.renameSync(rotFile.path);
      }

      final lines = event.lines.join('\n');
      file.writeAsStringSync('$lines\n', mode: FileMode.writeOnlyAppend, flush: true);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }
}
