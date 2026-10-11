/// Represents an in-app advertisement or promotional banner
/// configured exclusively through the Admin Dashboard.
class Advertisement {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? targetUrl;
  final bool isActive;
  /// Admin-selected close button option:
  /// - 'icon': circular '✕' icon only
  /// - 'text_and_cross': "Close ✕" button
  /// - 'text_only': "Skip / Close" text only
  final String closeButtonType;
  final int displayOrder;
  final DateTime? createdAt;

  const Advertisement({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.targetUrl,
    this.isActive = true,
    this.closeButtonType = 'icon',
    this.displayOrder = 0,
    this.createdAt,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Special Announcement',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      targetUrl: json['target_url'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      closeButtonType: json['close_button_type'] as String? ?? 'icon',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'is_active': isActive,
      'close_button_type': closeButtonType,
      'display_order': displayOrder,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Advertisement copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? targetUrl,
    bool? isActive,
    String? closeButtonType,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return Advertisement(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      targetUrl: targetUrl ?? this.targetUrl,
      isActive: isActive ?? this.isActive,
      closeButtonType: closeButtonType ?? this.closeButtonType,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
