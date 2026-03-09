
import os
import sys
import jieba.analyse
import numpy as np
from PIL import Image, ImageDraw
from docx import Document
from wordcloud import WordCloud
import matplotlib.pyplot as plt

def read_docx(file_path):
    """
    读取 Word 文档内容
    """
    if not os.path.exists(file_path):
        print(f"错误: 文件 {file_path} 不存在。")
        return ""
    
    try:
        doc = Document(file_path)
        full_text = []
        for para in doc.paragraphs:
            full_text.append(para.text)
        return '\n'.join(full_text)
    except Exception as e:
        print(f"读取 Word 文档时出错: {e}")
        return ""

def create_ellipse_mask(width, height):
    """
    创建一个椭圆形的遮罩
    背景为白色 (255)，椭圆区域为黑色 (0)
    """
    # 创建一个白色背景的图像
    img = Image.new("L", (width, height), 255)
    draw = ImageDraw.Draw(img)
    
    # 绘制黑色椭圆
    # 留出一点边距
    margin = 20
    draw.ellipse((margin, margin, width - margin, height - margin), fill=0)
    
    return np.array(img)

def generate_3d_dynamic_html(keywords_dict, output_file='wordcloud_3d.html'):
    """
    生成 3D 动态旋转词云的 HTML 文件
    使用 TagCanvas.js
    """
    print("正在生成 3D 动态词云 HTML...")
    
    # 构建 HTML 模板
    # 使用 TagCanvas 的 CDN
    # shape='sphere' 是球体，'hcylinder' 是水平圆柱（有点像椭圆）
    html_template = """
<!DOCTYPE html>
<html>
  <head>
    <title>3D 动态词云</title>
    <meta charset="utf-8">
    <script src="https://www.goat1000.com/tagcanvas.min.js" type="text/javascript"></script>
    <style>
      body { font-family: sans-serif; background-color: #f0f0f0; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
      #myCanvasContainer { width: 800px; height: 600px; background-color: white; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
      h1 { color: #333; margin-bottom: 20px; }
    </style>
    <script type="text/javascript">
      window.onload = function() {
        try {
          TagCanvas.Start('myCanvas','tags',{
            textColour: null,
            outlineColour: '#ff00ff',
            reverse: true,
            depth: 0.8,
            maxSpeed: 0.05,
            textFont: 'PingFang SC, Microsoft YaHei, sans-serif',
            textHeight: 25,
            wheelZoom: true,
            shape: 'sphere',
            initial: [0.1,-0.1],
            freezeActive: true,
            shuffleTags: true,
            pulsateTo: 0.8,
            shadow: '#ccf',
            shadowBlur: 3,
            weight: true,
            weightMode: 'size',
            weightSize: 1.0,
            weightGradient: {
             0:    '#f00', // red
             0.33: '#ff0', // yellow
             0.66: '#0f0', // green
             1:    '#00f'  // blue
            }
          });
        } catch(e) {
          // something went wrong, hide the canvas container
          document.getElementById('myCanvasContainer').style.display = 'none';
        }
      };
    </script>
  </head>
  <body>
    <h1>3D 动态词云展现</h1>
    <div id="myCanvasContainer">
      <canvas width="800" height="600" id="myCanvas">
        <p>Your browser does not support the canvas tag.</p>
      </canvas>
    </div>
    <div id="tags" style="display: none;">
      <ul>
        {tags_list}
      </ul>
    </div>
  </body>
</html>
    """
    
    # 构建标签列表
    # 格式: <li><a href="#" style="font-size: {size}px">{word}</a></li>
    # TagCanvas 支持 data-weight 属性，或者通过字体大小控制权重
    # 我们这里使用 font-size 来映射权重
    
    tags_html = []
    # 归一化权重到字体大小范围 (e.g., 12px - 60px)
    if not keywords_dict:
        return
        
    max_weight = max(keywords_dict.values())
    min_weight = min(keywords_dict.values())
    
    for word, weight in keywords_dict.items():
        # 简单的线性映射
        if max_weight == min_weight:
            size = 24
        else:
            size = 12 + (weight - min_weight) / (max_weight - min_weight) * 48
        
        # 为了让 TagCanvas 识别权重，我们可以使用 data-weight 或者直接在样式里写
        # 这里为了简单和兼容，直接用 font-size (TagCanvas default weightMode is 'size')
        # 链接 href="#" 设为空，防止点击跳转
        tags_html.append(f'<li><a href="#" style="font-size: {size}ex">{word}</a></li>')
    
    html_content = html_template.replace("{tags_list}", "\n".join(tags_html))
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"3D 动态词云 HTML 已保存至: {output_file}")

def generate_wordcloud(text, output_file='wordcloud.png'):
    """
    根据文本生成词云 (椭圆形)
    """
    if not text.strip():
        print("文本内容为空，无法生成词云。")
        return

    print("正在提取关键词...")
    # 使用 jieba 提取关键词
    keywords = jieba.analyse.extract_tags(text, topK=200, withWeight=True)
    keywords_dict = {word: weight for word, weight in keywords}
    
    if not keywords_dict:
        print("未提取到有效关键词。")
        return

    print(f"提取到 {len(keywords_dict)} 个关键词。")

    # 1. 生成静态椭圆词云
    print("正在生成静态椭圆词云...")
    
    # 设置尺寸
    width = 1200
    height = 800
    
    # 创建椭圆 mask
    mask = create_ellipse_mask(width, height)

    # 设置字体路径
    font_path = '/System/Library/Fonts/PingFang.ttc'
    if not os.path.exists(font_path):
        font_path = '/System/Library/Fonts/STHeiti Light.ttc' 
        if not os.path.exists(font_path):
             font_path = None

    # 配置词云
    wc = WordCloud(
        font_path=font_path,
        background_color='white',
        width=width,
        height=height,
        max_words=200,
        mask=mask, # 应用 mask
        contour_width=3, # 轮廓线宽度
        contour_color='steelblue', # 轮廓线颜色
        max_font_size=150,
        random_state=42,
        colormap='viridis',
        margin=2
    )

    wc.generate_from_frequencies(keywords_dict)
    wc.to_file(output_file)
    print(f"静态椭圆词云已保存至: {output_file}")
    
    # 2. 生成 3D 动态词云
    html_output = output_file.replace('.png', '_3d.html')
    generate_3d_dynamic_html(keywords_dict, html_output)

def main():
    if len(sys.argv) < 2:
        print("使用方法: python wordcloud_generator.py <word文档路径> [输出图片路径]")
        # 默认寻找当前目录下的 test.docx
        input_file = "test.docx"
        if not os.path.exists(input_file):
             print(f"未提供参数且默认文件 {input_file} 不存在。")
             return
    else:
        input_file = sys.argv[1]

    output_file = "wordcloud.png"
    if len(sys.argv) > 2:
        output_file = sys.argv[2]

    print(f"正在读取文档: {input_file}")
    text = read_docx(input_file)
    
    if text:
        generate_wordcloud(text, output_file)

if __name__ == "__main__":
    main()
