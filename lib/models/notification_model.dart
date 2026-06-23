class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final String? referenceTable;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.referenceTable,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json["id"] is String ? int.parse(json["id"]) : json["id"],
      userId: json["user_id"] is String ? int.parse(json["user_id"]) : json["user_id"],
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      type: json["type"] ?? "INFO",
      referenceTable: json["reference_table"],
      referenceId: json["reference_id"] != null && json["reference_id"].toString().isNotEmpty && json["reference_id"] != "null"
          ? (json["reference_id"] is String ? int.tryParse(json["reference_id"]) : json["reference_id"])
          : null,
      isRead: json["is_read"] == true || json["is_read"] == 'true',
      createdAt: json["created_at"] != null ? DateTime.parse(json["created_at"]) : DateTime.now(),
    );
  }
}
