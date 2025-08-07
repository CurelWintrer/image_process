class ImageModel {
  final int imageID;
  final String md5;
  final String? First;
  final String? Second;
  final String? Third;
  final String? Fourth;
  final String? Fifth;
  final String? imgName;
  late final String imgPath;
  final String? chinaElementName;
  String? caption;
  final int? state;
  final int? imageListID;
  final String created_at;
  final String updated_at;

  ImageModel({
    required this.imageID,
    required this.md5,
    this.First,
    this.Second,
    this.Third,
    this.Fourth,
    this.Fifth,
    required this.imgName,
    required this.imgPath,
    required this.chinaElementName,
    required this.caption,
    required this.state,
    required this.imageListID,
    required this.created_at,
    required this.updated_at,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      imageID: json['imageID'],
      md5: json['md5'],
      First: json['First'],
      Second: json['Second'],
      Third: json['Third'],
      Fourth: json['Fourth'],
      Fifth: json['Fifth'],
      imgName: json['imgName'],
      imgPath: json['imgPath'],
      chinaElementName: json['chinaElementName'],
      caption: json['caption'],
      state: json['state'],
      imageListID: json['imageListID'],
      created_at: json['created_at'],
      updated_at: json['updated_at'],
    );
  }

   String getTitleAtLevel(int level) {
    switch (level) {
      case 1:
        return First ?? '';
      case 2:
        return Second ?? '';
      case 3:
        return Third ?? '';
      case 4:
        return Fourth ?? '';
      case 5:
        return Fifth ?? '';
      default:
        return '';
    }
  }

  // 添加copyWith方法
  ImageModel copyWith({
    int? imageID,
    String? md5,
    String? First,
    String? Second,
    String? Third,
    String? Fourth,
    String? Fifth,
    String? imgName,
    String? imgPath,
    String? chinaElementName,
    String? caption,
    int? state,
    int? imageListID,
    String? created_at,
    String? updated_at,
  }) {
    return ImageModel(
      imageID: imageID ?? this.imageID,
      md5: md5 ?? this.md5,
      First: First ?? this.First,
      Second: Second ?? this.Second,
      Third: Third ?? this.Third,
      Fourth: Fourth ?? this.Fourth,
      Fifth: Fifth ?? this.Fifth,
      imgName: imgName ?? this.imgName,
      imgPath: imgPath ?? this.imgPath,
      chinaElementName: chinaElementName ?? this.chinaElementName,
      caption: caption ?? this.caption,
      state: state ?? this.state,
      imageListID: imageListID ?? this.imageListID,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  // 可选：添加toJson方法用于序列化
  Map<String, dynamic> toJson() {
    return {
      'imageID': imageID,
      'md5': md5,
      'First': First,
      'Second': Second,
      'Third': Third,
      'Fourth': Fourth,
      'Fifth': Fifth,
      'imgName': imgName,
      'imgPath': imgPath,
      'chinaElementName': chinaElementName,
      'caption': caption,
      'state': state,
      'imageListID': imageListID,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  // 可选：添加toString方法便于调试
  @override
  String toString() {
    return 'ImageModel(imageID: $imageID, imgName: $imgName, caption: $caption)';
  }
}