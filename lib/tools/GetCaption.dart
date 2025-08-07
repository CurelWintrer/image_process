import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_process/model/image_model.dart';
import 'package:image_process/user_session.dart';

// AI模型响应结构
class AiResponse {
  final String content;

  AiResponse({required this.content});

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    return AiResponse(content: json['choices'][0]['message']['content']);
  }
}

class ImageService {
  static final String apiKey =
      UserSession().apiKey;
  static final String apiUrl =
      UserSession().apiUrl;
  static final String token=UserSession().token??'';

  // 下载图片并转换为base64
  static Future<String> downloadImageAndConvertToBase64(String imgUrl) async {
    try {
      final response = await http.get(Uri.parse(imgUrl));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        throw Exception('图片下载失败, HTTP状态码: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('图片处理错误: $e');
    }
  }

  static List<String> getTwoPart(String input) {
    // 使用 split() 方法根据 '/' 进行分割
    List<String> result = input.split('/');
    return result;
  }

  static String? getPomat(ImageModel image) {
    List<String> result = getTwoPart(image.chinaElementName??'');
    switch (image.Second) {
      case '诗词' || '古典文学':
        return '开篇句式（任选）：1、这是${result[0]}《${result[1]}》的部分书法作品图片。2、图中展示的是${result[0]}《${result[1]}》中描绘的某一场景。3、图像还原了《${result[1]}》中典型意境的表现。';

      case '成语' || '谚语' || '歇后语':
        return '1、图中展示的是${result[0]}"${result[1]}"的视觉再现。2、这是${result[0]}“${result[1]}”所表达含义的具象画面。3、该图表现了${result[0]}“${result[1]}”的形象意境。';

      case '神话传说' || '历史故事':
        return '1、这是${result[0]}“${result[1]}”的画面再现。2、图中展现的是${result[0]}“${result[1]}”的经典场景。3、这是关于${result[0]}“${result[1]}”传说的视觉演绎。';

      default:
        return '';
    }
  }

  // 调用大模型API生成描述
  static Future<AiResponse> getImageCaptionFromAI(
    String base64Image,
    ImageModel image,
  ) async {
    String? text = getPomat(image);
    List<String> result = getTwoPart(image.chinaElementName??'');
    print(text);

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gemini-2.5-pro",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text":
                    """你是一个专业的中国文化元素分析师。你的任务是为一张关于${result[0]}“${result[1]}”的图片撰写一段符合特定结构和风格的详细描述。这张图片的上下文主题是：“${result[1]}”。
                请严格遵循以下规则：
                1. 开篇点题：第一句话必须点明主题，是陈述句，不得使用逗号、顿号、斜杠。必须带上大类“${result[0]}”。准确使用原名，不得模糊或替换。
                2. 分写内容：客观详尽描述图中主体元素的外观、形态、颜色、材质等视觉细节。如是文字作品，按照作品文字排列方式注明“横排X列，竖排X行”。
                3. 结尾总写：以“展现出……的独特韵味与……”或“尽显……的……”句式结尾，升华主题，不得使用逗号、顿号、斜杠。
                4. 语言要求：字数不少于30字，语言专业、客观、中立；不得有错别字、语法错误；仅一段文字，不得换行。
                5. 描述重点：聚焦图中核心元素，避免泛化；必要时结合搜索结果补充信息。
                
                开篇示例：$text;(可以适当改成类似的说法)

                以下为Caption样例：
                1)图片中展示的是武英殿的宫门。该宫门建筑屋顶为黄色琉璃瓦，殿身红墙彩饰，栏杆白石雕就、造型规整。宫门气势恢宏庄严，尽显中式古建筑的典雅厚重。
                2)图中展示的是毛公鼎内部分的大篆铭文。背景为棕褐色，铭文文字呈浅米色，铭文以大篆字体书写，字形大小错落有致，笔画线条或曲或直、古朴浑厚，该图横排五列，竖排七行，共三十五个字。展现出西周时期文字的独特韵味与书法艺术。
                3)这是人物画《朱佛女画像轴》的图片。画作背景为暖棕色调，画中她头戴华丽凤冠，身着大红服饰，饰有精美龙纹等图案，尽显尊贵，手中拿着白色的笏板，端坐在椅子上。展现出明代贵族女性服饰的独特韵味与礼仪规制。
                4）这是演练少林功夫的场景。背景为红砖墙与古建筑，人物身着传统练功服，两位僧人跃起施展武术侧踢，后排数位僧人身着灰色僧袍，整齐盘腿静坐。展现出少林武术的独特韵味与实战风采。
                5）这是戏曲京剧中旦角的图片。背景为绘制着艳丽牡丹与翠绿枝叶的传统布景，人物身着华丽的传统戏服，头戴精致凤冠，面部妆容精致，双手轻握白色水袖于身前。展现出京剧艺术的古典韵味与独特美感。
                6）这是宋代传统服饰褙子的图片。褙子整体呈长袍样式，颜色为浅褐色，边缘饰有深色花纹。对襟设计，衣袖宽阔，面料纹理清晰。展现出传统服饰文化的独特韵味与历史底蕴。
                7）这是泉州提线木偶表演的场景。背景为简洁的深色幕布，男性木偶双臂张开正在表演，身着带有金色配饰和蓝色部件、布满复杂花纹的红色传统戏服，头戴精致帽子，长须垂胸，表情威严。展现出传统木偶戏的独特韵味与表演风采。
                8）图中展示的是成语青梅竹马。“青梅竹马”四字以手写书法形式呈现于画面中央上方，字体为黑色，笔触富有书法韵味；右侧标注“康凯鹏 著”，字体较小；画面下方有两名孩童形象，左侧孩童身穿蓝色上衣搭配橙色下装，右手抬起；整体为水彩插画风格。展现出“青梅竹马”成语所蕴含的传统文化韵味与童真意境，尽显中国风插画的艺术魅力与文化传承价值
                """,
              },
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
              },
            ],
          },
        ],
        "max_tokens": 300,
      }),
    );
    if (response.statusCode == 200) {
      return AiResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('大模型请求失败: ${response.statusCode}, ${response.body}');
    }
  }

  // 更新数据库中的caption
  static Future<void> updateImageCaption({
    required int imageID,
    required String newCaption,
    String? token,
  }) async {
    print(token);
    final response = await http.post(
      Uri.parse('${UserSession().baseUrl}/api/image/update-captions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "captions": [
          {"imageID": imageID, "caption": newCaption},
        ],
      }),
    );

    print(response.body);

    if (response.statusCode != 200) {
      throw Exception('数据库更新失败: ${response.statusCode}, ${response.body}');
    }
  }
}
