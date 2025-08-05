class TitleTypes {
  final List<String> first;
  final List<String> second;
  final List<String> third;
  final List<String> fourth;
  final List<String> fifth;

  TitleTypes({
    required this.first,
    required this.second,
    required this.third,
    required this.fourth,
    required this.fifth,
  });

  factory TitleTypes.fromJson(Map<String, dynamic> json) {
    return TitleTypes(
      first: List<String>.from(json['First']),
      second: List<String>.from(json['Second']),
      third: List<String>.from(json['Third']),
      fourth: List<String>.from(json['Fourth']),
      fifth: List<String>.from(json['Fifth']),
    );
  }
}