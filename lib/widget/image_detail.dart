import 'package:flutter/material.dart';
import 'package:image_process/model/image_model.dart';
import 'package:image_process/model/image_state.dart';
import 'package:image_process/user_session.dart';

// 定义回调类型
typedef ImageUpdateCallback = void Function(ImageModel updatedImage);

class ImageDetail extends StatefulWidget {
  final ImageModel image;
  final ImageUpdateCallback? onImageUpdated;
  final VoidCallback? onClose;
  final Future<void> Function()? onDownload; // 可选的下载回调
  final Future<void> Function()? onUpload; // 可用的上传回调
  final Future<String> Function()? onAIGenerate; // AI生成描述回调

  const ImageDetail({
    super.key,
    required this.image,
    this.onImageUpdated,
    this.onClose,
    this.onDownload,
    this.onUpload,
    this.onAIGenerate,
  });

  @override
  State<ImageDetail> createState() => _ImageDetailState();
}

class _ImageDetailState extends State<ImageDetail> {
  late ImageModel currentImage;
  late TextEditingController captionController;

  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
    captionController = TextEditingController(text: widget.image.caption);
  }

  @override
  void didUpdateWidget(ImageDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      currentImage = widget.image;
      captionController.text = widget.image.caption;
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    if (widget.onImageUpdated != null) {
      widget.onImageUpdated!(currentImage);
    }
  }

  // 图片下载处理
  Future<void> _downloadImage() async {
    if (widget.onDownload != null) {
      await widget.onDownload!();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载功能已触发')));
    }
  }

  // 图片上传处理
  Future<void> _uploadImage() async {
    if (widget.onUpload != null) {
      await widget.onUpload!();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上传功能已触发')));
    }
  }

  // 显示MD5信息
  void _showMd5Info() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('图片MD5信息'),
        content: Text('MD5: ${currentImage.md5}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 更新图片状态
  Future<void> _setImageState(int state) async {
    try {
      // 创建更新后的图片对象
      setState(() {
        currentImage = currentImage.copyWith(state: state);
      });

      _notifyUpdate();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('状态已更新为: ${ImageState.getStateText(state)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
    }
  }

  // 更新图片描述
  Future<void> _updateCaption(String newCaption) async {
    try {
      setState(() {
        currentImage = currentImage.copyWith(caption: newCaption);
      });

      _notifyUpdate();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('描述已更新')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: ${e.toString()}')));
    }
  }

  // AI生成描述
  Future<void> _generateAICaption() async {
    if (widget.onAIGenerate != null) {
      try {
        final newCaption = await widget.onAIGenerate!();
        captionController.text = newCaption;
        await _updateCaption(newCaption);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI生成失败: ${e.toString()}')));
      }
    } else {
      // 默认模拟实现
      const generatedCaption = "这是AI生成的详细描述，包含图片的主要内容和特点。";
      captionController.text = generatedCaption;
      await _updateCaption(generatedCaption);
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

  // 构建图片组件
  Widget _buildImageWidget() {
    final fullImagePath =
        '${UserSession().baseUrl}/img/${currentImage.imgPath}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          fullImagePath,
          fit: BoxFit.cover,
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
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
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
        color: theme.cardColor,
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
              Expanded(
                child: Text(
                  currentImage.chinaElementName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

          // 状态指示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ImageState.getStateColor(currentImage.state ?? 0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ImageState.getStateText(currentImage.state ?? 0),
              style: const TextStyle(color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

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
              _buildActionButton('MD5', Icons.fingerprint, _showMd5Info),
              Tooltip(
                message: '废弃',
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _setImageState(5),
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
              Tooltip(
                message: '通过',
                child: IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: () => _setImageState(4),
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
          _buildInfoItem('名称', currentImage.imgName),
          _buildInfoItem('路径', currentImage.imgPath),
          _buildInfoItem('MD5', currentImage.md5),
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
                onPressed: () => _updateCaption(captionController.text),
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
