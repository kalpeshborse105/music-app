/// Represents an in-app advertisement or promotional banner
/// configured exclusively through the Admin Dashboard.
class Advertisement {
  static const String placementPopup = 'popup';
  static const String placementHomePreRadio = 'home_pre_radio';
  static const String placementHomePostRecent = 'home_post_recent';
  static const String placementCatalogMid = 'catalog_mid';
  static const String placementLibraryMid = 'library_mid';
  static const String placementPlaylistMid = 'playlist_mid';

  static const List<Map<String, String>> placementOptions =
      <Map<String, String>>[
    <String, String>{
      'value': placementPopup,
      'label': 'App open popup',
    },
    <String, String>{
      'value': placementHomePreRadio,
      'label': 'Home — after header, before radio',
    },
    <String, String>{
      'value': placementHomePostRecent,
      'label': 'Home — after recently played',
    },
    <String, String>{
      'value': placementCatalogMid,
      'label': 'Home — middle of catalogue shelves',
    },
    <String, String>{
      'value': placementLibraryMid,
      'label': 'Library — middle of browse',
    },
    <String, String>{
      'value': placementPlaylistMid,
      'label': 'Playlist — middle of tracks',
    },
  ];

  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? targetUrl;
  final bool isActive;
  /// Admin-selected close button option (popup only):
  /// - 'icon': circular '✕' icon only
  /// - 'text_and_cross': "Close ✕" button
  /// - 'text_only': "Skip / Close" text only
  final String closeButtonType;
  final int displayOrder;
  final String placement;
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
    this.placement = placementPopup,
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
      placement: (json['placement'] as String?)?.trim().isNotEmpty == true
          ? (json['placement'] as String).trim()
          : placementPopup,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
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
      'placement': placement,
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
    String? placement,
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
      placement: placement ?? this.placement,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
