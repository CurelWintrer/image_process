import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/tools/DownloadHelper.dart';
import 'package:image_process/tools/GetCaption.dart';
import 'package:image_process/tools/UploadHelper%20.dart';
import 'package:image_process/user_session.dart';

// 定义回调类型
typedef ImageUpdateCallback = void Function(ImageModel updatedImage);
typedef UploadCallback = void Function(ImageModel uploadImage);
typedef onAIGenerateCallback = void Function(ImageModel updatedImage);
typedef onUpdateCaptionCallback = void Function(ImageModel updatedImage);
typedef onUpdateStateCallback = void Function(ImageModel updatedImage);
typedef onTitleEditedCallback = void Function(ImageModel updatedImage);

class ImageDetail extends StatefulWidget {
  final ImageModel image;
  final ImageUpdateCallback? onImageUpdated;
  final VoidCallback? onClose;
  final Future<void> Function()? onDownload; // 可选的下载回调
  final UploadCallback? onUpload; // 可用的上传回调
  final onAIGenerateCallback? onAIGenerate; // AI生成描述回调
  final onUpdateStateCallback? onUpdateState;
  final onUpdateCaptionCallback? onUpdateCaption;
  final onTitleEditedCallback? onTitleEdited;

  const ImageDetail({
    super.key,
    required this.image,
    this.onImageUpdated,
    this.onClose,
    this.onDownload,
    this.onUpload,
    this.onAIGenerate,
    this.onUpdateState,
    this.onUpdateCaption,
    this.onTitleEdited,
  });

  @override
  State<ImageDetail> createState() => _ImageDetailState();
}

class _ImageDetailState extends State<ImageDetail> {
  late ImageModel currentImage;
  late TextEditingController captionController;
  Size? _imageSize;

  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();

  bool _isLoadingCaption = false;

  bool _isDownloading = false;

  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
    captionController = TextEditingController(text: widget.image.caption);
    _getImageSize();
  }

  @override
  void didUpdateWidget(ImageDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      currentImage = widget.image;
      captionController.text = widget.image.caption ?? '';

      _getImageSize();
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  // 获取图片尺寸的方法
  Future<void> _getImageSize() async {
    try {
      final imageUrl = '${UserSession().baseUrl}/img/${currentImage.imgPath}';
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;

      // 使用 Image.memory 获取尺寸
      final ImageProvider imageProvider = MemoryImage(bytes);
      final Completer<Size> completer = Completer();

      imageProvider
          .resolve(createLocalImageConfiguration(context))
          .addListener(
            ImageStreamListener(
              (ImageInfo info, bool synchronousCall) {
                if (!completer.isCompleted) {
                  completer.complete(
                    Size(
                      info.image.width.toDouble(),
                      info.image.height.toDouble(),
                    ),
                  );
                }
              },
              onError: (exception, StackTrace? stackTrace) {
                if (!completer.isCompleted) {
                  completer.complete(Size(0, 0)); // 返回一个默认的 Size 对象
                }
              },
            ),
          );

      final size = await completer.future;
      if (size != null && mounted) {
        setState(() => _imageSize = size);
      }
    } catch (e) {
      print('获取图片尺寸失败: $e');
    }
  }

  // 统一状态更新方法
  void _updateState(ImageModel updatedImage) {
    setState(() => currentImage = updatedImage);
    // 通知所有可能的更新回调
    if (widget.onImageUpdated != null) widget.onImageUpdated!(updatedImage);
    if (widget.onUpload != null) widget.onUpload!(updatedImage);
    if (widget.onAIGenerate != null) widget.onAIGenerate!(updatedImage);
    if (widget.onUpdateCaption != null) widget.onUpdateCaption!(updatedImage);
    if (widget.onUpdateState != null) widget.onUpdateState!(updatedImage);
    if (widget.onTitleEdited != null) widget.onTitleEdited!(updatedImage);
  }

  // 图片下载处理
  Future<void> _downloadImage() async {
    try {
      await DownloadHelper.downloadImage(
        context: context,
        imgPath: currentImage.imgPath??'',
        imgName: currentImage.imgName ?? '',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载失败')));
    }
  }

  // 图片上传处理
  Future<void> _uploadImage() async {
    try {
      // 创建更新后的图片对象
      final response = await UploadHelper.pickAndUpload(
        context: context,
        imageID: currentImage.imageID,
      );
      // 创建更新后的图片对象
      final updatedImage = currentImage.copyWith(
        imgPath: response?['imgPath'],
        imgName: response?['fileName'],
        md5: response?['md5'],
        updated_at: DateTime.now().toIso8601String(),
      );
      _updateState(updatedImage);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: ${e.toString()}')));
    }
  }

  // 更新图片状态
  Future<void> _setImageState(int state) async {
    try {
      // 创建更新后的图片对象
      final respose = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/update-states'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "states": [
            {"imageID": currentImage.imageID, "state": state},
          ],
        }),
      );
      print(respose.body);
      if (respose.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('状态更新成功')));
      }

      final updatedImage = currentImage.copyWith(state: state);
      _updateState(updatedImage);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
    }
  }

  // 更新图片描述
  Future<void> _updateCaption() async {
    try {
      ImageService.updateImageCaption(
        imageID: currentImage.imageID,
        newCaption: captionController.text,
        token: UserSession().token,
      );
      final updatedImage = currentImage.copyWith(
        caption: captionController.text,
        updated_at: DateTime.now().toIso8601String(),
      );
      _updateState(updatedImage);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('caption更新成功')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
    }
  }

  // AI生成描述
  Future<void> _generateAICaption() async {
    // 获取安全上下文和保存组件挂载状态
    final BuildContext? safeContext = mounted ? context : null;

    try {
      // 显示加载对话框
      setState(() {
        _isLoadingCaption = true;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在更新图片描述...'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  
                  Navigator.of(context).pop();
                  setState(() {
                    _isLoadingCaption = false;
                  });
                  return;
                },
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      );

      try {
        // 1. 下载图片并转换为base64
        final base64Image = await ImageService.downloadImageAndConvertToBase64(
          '${UserSession().baseUrl}/img/${currentImage.imgPath}',
        );
        // 2. 调用AI模型生成新描述
        final aiResponse = await ImageService.getImageCaptionFromAI(
          base64Image,
          currentImage,
        );
        final newCaption = aiResponse.content;
        
        print(newCaption);

        // 3. 更新数据库
        await ImageService.updateImageCaption(
          imageID: currentImage.imageID,
          newCaption: newCaption,
          token: UserSession().token,
        );
        // 4. 更新本地状态
        final updatedImage = currentImage.copyWith(
          caption: newCaption,
          updated_at: DateTime.now().toIso8601String(),
        );
        setState(() {
          // currentImage=updatedImage;
          captionController.text=newCaption;
        });
        _updateState(updatedImage);
        if (safeContext == null) return;

        if (_isLoadingCaption) {
          Navigator.of(context).pop();
        }
        // 显示成功消息
        if (safeContext != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${currentImage.chinaElementName}描述更新成功!')),
          );
        }
      } catch (e) {
        // 显示错误
        if (safeContext != null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
        }
      }
    } catch (e) {
      if (safeContext != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI更新失败')));
      }
    }
  }

  Future<void> _updateName() async {
    final newTitle = _titleController.text.trim();

    try {
      // 调用API更新标题
      final response = await http.post(
        Uri.parse(
          '${UserSession().baseUrl}/api/image/update-china-element-name',
        ),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'imageID': currentImage.imageID,
          'chinaElementName': newTitle,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isEditingTitle = false;
          currentImage = currentImage.copyWith(chinaElementName: newTitle);
        });

        final updatedImage = currentImage.copyWith(chinaElementName: newTitle);
        _updateState(updatedImage);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新标题成功')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新标题失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('网络错误：$e')));
    }
  }

  // 构建分类标签
  Widget _buildClassificationTag(String title, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          Text(value, style: TextStyle(color: Colors.blue[800])),
        ],
      ),
    );
  }

  // 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }

  //构建图片组件
  Widget _buildImageWidget() {
    final fullImagePath =
        '${UserSession().baseUrl}/img/${currentImage.imgPath}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: InteractiveViewer(
          panEnabled: true, // 启用拖拽
          scaleEnabled: true, // 启用缩放
          minScale: 0.2, // 最小缩放比例
          maxScale: 4.0, // 最大缩放比例
          child: Image.network(
            fullImagePath,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '加载失败: ${error.toString()}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: text,
      child: IconButton(
        icon: Icon(icon, size: 24),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.blue[50],
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              // 标题部分
              Expanded(
                child: _isEditingTitle
                    ? TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        focusNode: focusNode,
                        // autofocus: true,
                        maxLines: null, // 允许多行文本
                        keyboardType: TextInputType.multiline,
                      )
                    : Text(
                        currentImage.chinaElementName ?? '',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              //编辑标题按钮
              _isEditingTitle
                  ? IconButton(
                      icon: Icon(Icons.save, size: 24),
                      onPressed: () {
                        _updateName();
                      },
                    )
                  : IconButton(
                      icon: Icon(Icons.edit, size: 24),
                      onPressed: () {
                        setState(() {
                          _isEditingTitle = true;
                          _titleController.text =
                              currentImage.chinaElementName ?? '';
                        });
                      },
                    ),
              // 显示图片分辨率
              // 在标题行分辨率显示部分
              if (_imageSize != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_imageSize!.width.toInt()}×${_imageSize!.height.toInt()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // 当任意一边小于720像素时显示红色，否则显示灰色
                      color:
                          (_imageSize!.width < 720 || _imageSize!.height < 720)
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                  ),
                ),

              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: widget.onClose,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 内容区域
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  // 宽屏布局（左右分栏）
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 左侧图片区域
                      Expanded(flex: 6, child: _buildImageWidget()),

                      const SizedBox(width: 20),

                      // 右侧信息区域
                      Expanded(flex: 4, child: _buildInfoColumn()),
                    ],
                  );
                } else {
                  // 窄屏布局（上下分栏）
                  return Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: _buildImageWidget(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: _buildInfoColumn()),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建信息列
  Widget _buildInfoColumn() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 操作按钮区域
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('下载', Icons.download, _downloadImage),
              _buildActionButton('上传', Icons.upload, _uploadImage),
              // _buildActionButton('MD5', Icons.fingerprint, _showMd5Info),
              Tooltip(
                message: '废弃',
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _setImageState(ImageState.Abandoned),
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
              Tooltip(
                message: '通过',
                child: IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: () => _setImageState(ImageState.Approved),
                  style: IconButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 分类标签
          const Text(
            '分类层级',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildClassificationTag('一级', currentImage.First),
              _buildClassificationTag('二级', currentImage.Second),
              _buildClassificationTag('三级', currentImage.Third),
              _buildClassificationTag('四级', currentImage.Fourth),
              _buildClassificationTag('五级', currentImage.Fifth),
            ],
          ),

          const SizedBox(height: 24),

          // 图片元信息
          const Text(
            '图片信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildInfoItem('ID', currentImage.imageID.toString()),
          _buildInfoItem('名称', currentImage.imgName ?? ''),
          _buildInfoItem('路径', currentImage.imgPath??''),
          _buildInfoItem('MD5', currentImage.md5??''),
          _buildInfoItem('创建时间', currentImage.created_at),
          _buildInfoItem('更新时间', currentImage.updated_at),
          if (currentImage.imageListID != null)
            _buildInfoItem('列表ID', currentImage.imageListID.toString()),

          const SizedBox(height: 24),

          // 详细描述编辑区域
          Row(
            children: [
              const Text(
                '详细描述',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () => _updateCaption(),
                child: const Text('手动更新'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _generateAICaption,
                child: const Text('AI生成'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: captionController,
            maxLines: 8,
            minLines: 2,
            focusNode: focusNode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '输入图片的详细描述...',
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
