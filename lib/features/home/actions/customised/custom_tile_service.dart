import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_tile_model.dart';

class CustomTileService {
  final _db = FirebaseFirestore.instance;

  Stream<List<CustomTileModel>> streamTiles(String projectId) {
    return _db
        .collection('tasks')
        .doc(projectId)
        .collection('custom_tiles')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CustomTileModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addTile(CustomTileModel tile) async {
    await _db
        .collection('tasks')
        .doc(tile.projectId)
        .collection('custom_tiles')
        .add(tile.toMap());
  }

  Future<void> deleteTile(String projectId, String tileId) async {
    await _db
        .collection('tasks')
        .doc(projectId)
        .collection('custom_tiles')
        .doc(tileId)
        .delete();
  }
}
