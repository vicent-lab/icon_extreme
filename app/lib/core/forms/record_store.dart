/// What the add/edit form needs from the data layer. Screens give the form a store;
/// the form never talks to the database itself.
abstract class RecordStore {
  Future<void> insert(Map<String, dynamic> data);
  Future<void> update(Object id, Map<String, dynamic> data);

  /// Returns false when nothing was removed (for example, the role is not allowed to delete it).
  Future<bool> delete(Object id);
}
