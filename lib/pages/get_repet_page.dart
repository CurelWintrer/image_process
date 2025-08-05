import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/user_session.dart';
import 'package:image_process/widget/image_detail.dart';

class DuplicateGroup {
  final String chinaElementName;
  final List<ImageModel> images;

  DuplicateGroup({required this.chinaElementName, required this.images});

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List;
    final images = imagesJson.map((i) => ImageModel.fromJson(i)).toList();

    return DuplicateGroup(
      chinaElementName: json['chinaElementName'],
      images: images,
    );
  }
}

class GetRepetPage extends StatefulWidget {
  const GetRepetPage({Key? key}) : super(key: key);

  @override
  _GetRepetPageState createState() => _GetRepetPageState();
}

class _GetRepetPageState extends State<GetRepetPage> {
  List<DuplicateGroup> duplicateGroups = [];
  ImageModel? selectedImage;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDuplicateGroups();
  }

  Future<void> _fetchDuplicateGroups() async {
    final token = UserSession().token;
    if (token == null) {
      setState(() {
        errorMessage = "未登录，请重新登录";
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/api/image/duplicate-elements'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final groupsJson = data['duplicates'] as List;
        setState(() {
          duplicateGroups = groupsJson
              .map((groupJson) => DuplicateGroup.fromJson(groupJson))
              .toList();
          isLoading = false;

          // 默认选中第一组的第一个图片（如果存在）
          if (duplicateGroups.isNotEmpty &&
              duplicateGroups.first.images.isNotEmpty) {
            selectedImage = duplicateGroups.first.images.first;
          }
        });
      } else {
        setState(() {
          errorMessage = "请求失败: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "请求异常: $e";
        isLoading = false;
      });
    }
  }

   // 更新分组中的图片
  void _updateImageInGroups(ImageModel updatedImage) {
    setState(() {
      // 遍历所有分组和图片，更新匹配的图片
      for (var group in duplicateGroups) {
        for (int i = 0; i < group.images.length; i++) {
          if (group.images[i].imageID == updatedImage.imageID) {
            group.images[i] = updatedImage;
            // 如果更新的是当前选中的图片，则更新selectedImage
            if (selectedImage != null && selectedImage!.imageID == updatedImage.imageID) {
              selectedImage = updatedImage;
            }
            break;
          }
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (duplicateGroups.isEmpty) {
      return const Center(child: Text('未找到重复的图片'));
    }

    return Scaffold(
      body: Row(
        children: [
          // 左侧分组列表
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
              ),
              child: ListView.builder(
                itemCount: duplicateGroups.length,
                itemBuilder: (context, groupIndex) {
                  final group = duplicateGroups[groupIndex];
                  return Container(
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 分组标题
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            group.chinaElementName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 分组内的图片网格
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: group.images.length,
                          itemBuilder: (context, imageIndex) {
                            final image = group.images[imageIndex];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedImage = image;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedImage?.imageID == image.imageID
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        '${UserSession().baseUrl}/img/${image.imgPath}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(Icons.broken_image, color: Colors.grey),
                                          );
                                        },
                                      ),
                                      // 图片状态的角标
                                      if (image.state == ImageState.Abandoned)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      if (image.state == ImageState.Approved)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 右侧图片详情
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: selectedImage != null
                  ? ImageDetail(
                      image: selectedImage!,
                      onImageUpdated: (updatedImage) {
                        setState(() {
                          selectedImage = updatedImage;
                        });
                        _updateImageInGroups(updatedImage);
                      },
                      onUpdateState: (updatedImage) {
                        setState(() {
                          selectedImage = updatedImage;
                        });
                        _updateImageInGroups(updatedImage);
                      },
                      onUpdateCaption: (updatedImage) {
                        setState(() {
                          selectedImage = updatedImage;
                        });
                        _updateImageInGroups(updatedImage);
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('请从左侧选择一张图片', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
