class NoteKind {
  static const deposit = 'deposit';
  static const electricity = 'electricity';
  static const rent = 'rent';
}

class Note {
  final int? id;
  final int tenantId;
  final int? roomId;
  final String text;
  final String? imagePath;
  final String? kind;
  final double? amount;
  final bool isDone;
  final String createdAt;

  Note({
    this.id,
    required this.tenantId,
    this.roomId,
    required this.text,
    this.imagePath,
    this.kind,
    this.amount,
    this.isDone = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'room_id': roomId,
      'text': text,
      'image_path': imagePath,
      'kind': kind,
      'amount': amount,
      'is_done': isDone ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      roomId: map['room_id'] as int?,
      text: map['text'] as String,
      imagePath: map['image_path'] as String?,
      kind: map['kind'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      isDone: (map['is_done'] as int?) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}
