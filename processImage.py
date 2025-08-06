import torch
from PIL import Image
from transformers import CLIPProcessor, CLIPModel
import torchvision.transforms as T
from torchvision import models
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import os
import torch.nn as nn

# 尝试以本地文件方式加载模型，避免联网超时
try:
    clip_model = CLIPModel.from_pretrained(
        "openai/clip-vit-base-patch16", local_files_only=True
    )
    clip_processor = CLIPProcessor.from_pretrained(
        "openai/clip-vit-base-patch16", local_files_only=True
    )
except Exception as e:
    print("Warning: CLIP 模型加载失败，将尝试在线下载，可能导致超时", e)
    clip_model = CLIPModel.from_pretrained("openai/clip-vit-base-patch16")
    clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch16")

# 加载 ResNet 模型，建议预先手动下载权重或使用 local_files_only
try:
    resnet_model = models.resnet50(pretrained=True)
except Exception as e:
    print("Warning: ResNet50 模型加载失败，使用无预训练模型", e)
    resnet_model = models.resnet50(pretrained=False)
resnet_model.eval()


def extract_clip_features(image_path):
    image = Image.open(image_path).convert("RGB")
    inputs = clip_processor(images=image, return_tensors="pt", padding=True)
    with torch.no_grad():
        features = clip_model.get_image_features(**inputs)
    return features.squeeze().cpu().numpy()


def extract_resnet_features(image_path):
    image = Image.open(image_path).convert("RGB")
    transform = T.Compose([
        T.Resize(256),
        T.CenterCrop(224),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225])
    ])
    image = transform(image).unsqueeze(0)
    with torch.no_grad():
        features = nn.Sequential(*list(resnet_model.children())[:-1])(image)
    return features.squeeze().cpu().numpy()


def calculate_similarity(features1, features2):
    return cosine_similarity(
        features1.reshape(1, -1), features2.reshape(1, -1)
    )[0][0]


def find_similar_images(image_folder):
    # 收集所有图像路径
    image_paths = [
        os.path.join(image_folder, f)
        for f in os.listdir(image_folder)
        if f.lower().endswith(('jpg','jpeg','png'))
    ]
    # 批量加载 PIL 图片
    pil_images = [Image.open(p).convert("RGB") for p in image_paths]

    # —— 批量提取 CLIP 特征 —— 
    inputs = clip_processor(images=pil_images, return_tensors="pt", padding=True)
    with torch.no_grad():
        clip_feats = clip_model.get_image_features(**inputs).cpu().numpy()

    # —— 批量提取 ResNet 特征 —— 
    transform = T.Compose([
        T.Resize(256),
        T.CenterCrop(224),
        T.ToTensor(),
        T.Normalize(mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225]),
    ])
    batch_tensor = torch.stack([transform(img) for img in pil_images])
    with torch.no_grad():
        resnet_feats = nn.Sequential(*list(resnet_model.children())[:-1])(
            batch_tensor
        ).squeeze().cpu().numpy()

    # 然后再做余弦相似度比较
    similarity_groups = []
    for i in range(len(image_paths)):
        group = {image_paths[i]}
        for j in range(i+1, len(image_paths)):
            s1 = cosine_similarity(
                clip_feats[i].reshape(1,-1),
                clip_feats[j].reshape(1,-1)
            )[0][0]
            s2 = cosine_similarity(
                resnet_feats[i].reshape(1,-1),
                resnet_feats[j].reshape(1,-1)
            )[0][0]
            if s1>0.98 and s2>0.98:
                group.add(image_paths[j])
        similarity_groups.append(sorted(group))
    return similarity_groups


if __name__ == "__main__":
    import sys
    folder = sys.argv[1] if len(sys.argv) > 1 else None
    if not folder or not os.path.isdir(folder):
        print("Usage: python processImage.py <image_folder>")
        sys.exit(1)
    groups = find_similar_images(folder)
    for g in groups:
        print("Group of similar images:", g)
