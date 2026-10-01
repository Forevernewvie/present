#!/usr/bin/env python3
"""
스토어 배포용 고품질 그래픽 자산 자동 생성 스크립트
- Google Play 스토어 규격:
  - 512x512 앱 아이콘 (32-bit PNG)
  - 1024x500 그래픽 이미지 (Feature Graphic)
  - 1080x2400 스마트폰 스크린샷 4종
- Apple App Store 규격:
  - 1024x1024 앱 아이콘 (RGB, 알파 채널 제거)
  - 1290x2796 6.7인치 스크린샷 4종 (iPhone 15/16 Pro Max 기준)
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAIN_DIR = "/Users/jaebinchoi/.gemini/antigravity/brain/6c5f6d49-34d5-4ad1-8981-8de29e652803"
OUTPUT_DIR = os.path.join(BASE_DIR, "assets", "store")

FONT_PATH = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def get_font(size, weight="bold"):
    # 6: Bold, 4: SemiBold, 2: Medium, 0: Regular
    index = 6 if weight == "bold" else (4 if weight == "semi" else (2 if weight == "medium" else 0))
    try:
        return ImageFont.truetype(FONT_PATH, size, index=index)
    except Exception:
        return ImageFont.load_default()


def create_linear_gradient(width, height, top_color, bottom_color):
    base = Image.new("RGBA", (width, height), top_color)
    top_r, top_g, top_b = top_color[:3]
    bot_r, bot_g, bot_b = bottom_color[:3]

    gradient = Image.new("RGBA", (1, height))
    for y in range(height):
        ratio = y / float(height)
        r = int(top_r + (bot_r - top_r) * ratio)
        g = int(top_g + (bot_g - top_g) * ratio)
        b = int(top_b + (bot_b - top_b) * ratio)
        gradient.putpixel((0, y), (r, g, b, 255))

    return gradient.resize((width, height), Image.Resampling.BILINEAR)


def create_rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), size], radius=radius, fill=255)
    return mask


def draw_centered_text(draw, y, title, subtitle, width, title_font, sub_font):
    # 타이틀
    t_bbox = draw.textbbox((0, 0), title, font=title_font)
    t_w = t_bbox[2] - t_bbox[0]
    t_h = t_bbox[3] - t_bbox[1]
    t_x = (width - t_w) // 2
    draw.text((t_x, y), title, fill=(28, 28, 30), font=title_font)

    # 서브 타이틀
    s_bbox = draw.textbbox((0, 0), subtitle, font=sub_font)
    s_w = s_bbox[2] - s_bbox[0]
    s_x = (width - s_w) // 2
    sub_y = y + t_h + 24
    draw.text((s_x, sub_y), subtitle, fill=(108, 108, 112), font=sub_font)

    return sub_y + (s_bbox[3] - s_bbox[1])


def generate_screenshot(target_w, target_h, screen_img_path, title, subtitle, output_path, is_ios=False):
    # 1. 배경 생성 (따뜻한 베이지-살구 그라디언트)
    top_bg = (255, 253, 250, 255)
    bot_bg = (250, 240, 230, 255)
    canvas = create_linear_gradient(target_w, target_h, top_bg, bot_bg)

    draw = ImageDraw.Draw(canvas)

    # 폰트 스케일 계산
    scale = target_w / 1080.0
    title_size = int(62 * scale)
    sub_size = int(34 * scale)

    title_font = get_font(title_size, "bold")
    sub_font = get_font(sub_size, "medium")

    # 상단 여백
    top_margin = int(140 * scale)
    text_bottom = draw_centered_text(draw, top_margin, title, subtitle, target_w, title_font, sub_font)

    # 2. 목업 디바이스 프레임 배치
    # 화면 이미지를 불러와서 디바이스 비율에 맞게 리사이징
    screen_src = Image.open(screen_img_path).convert("RGBA")
    
    # 디바이스 가로 크기: 캔버스 가로의 약 82%
    device_w = int(target_w * 0.82)
    device_ratio = screen_src.height / float(screen_src.width)
    device_h = int(device_w * device_ratio)

    # 화면 리사이즈
    screen_resized = screen_src.resize((device_w, device_h), Image.Resampling.LANCZOS)

    # 디바이스 모서리 라운딩 (iOS는 더 둥글게, Android도 현대적 라운딩)
    radius = int(58 * scale) if is_ios else int(48 * scale)
    mask = create_rounded_mask((device_w, device_h), radius)

    # 그림자(Drop Shadow) 생성
    shadow_offset_y = int(30 * scale)
    shadow_blur = int(45 * scale)
    shadow = Image.new("RGBA", (device_w + shadow_blur * 2, device_h + shadow_blur * 2), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        [(shadow_blur, shadow_blur), (device_w + shadow_blur, device_h + shadow_blur)],
        radius=radius,
        fill=(0, 0, 0, 45)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur // 2))

    # 프레임 위치 계산 (텍스트 하단에서 적당한 마진)
    frame_y = text_bottom + int(80 * scale)
    frame_x = (target_w - device_w) // 2

    # 그림자 합성
    shadow_x = frame_x - shadow_blur
    shadow_y = frame_y - shadow_blur + shadow_offset_y
    canvas.paste(shadow, (shadow_x, shadow_y), shadow)

    # 화면 붙이기 (둥근 마스크 적용)
    screen_frame = Image.new("RGBA", (device_w, device_h))
    screen_frame.paste(screen_resized, (0, 0), mask)

    # 세련된 베젤 테두리 그리기
    border_draw = ImageDraw.Draw(screen_frame)
    border_draw.rounded_rectangle(
        [(0, 0), (device_w - 1, device_h - 1)],
        radius=radius,
        outline=(220, 220, 225, 180),
        width=int(4 * scale)
    )

    canvas.paste(screen_frame, (frame_x, frame_y), screen_frame)

    # iOS는 알파 채널이 없어야 하므로 RGB 변환
    if is_ios:
        final_img = canvas.convert("RGB")
    else:
        final_img = canvas

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final_img.save(output_path, "PNG", optimize=True)
    print(f"Generated: {output_path} ({target_w}x{target_h})")


def generate_store_icons():
    icon_src_path = os.path.join(BASE_DIR, "assets", "icon", "app_icon.png")
    icon_src = Image.open(icon_src_path)

    # 1. Google Play 아이콘: 512x512
    play_icon_path = os.path.join(OUTPUT_DIR, "playstore_icon_512.png")
    play_icon = icon_src.resize((512, 512), Image.Resampling.LANCZOS)
    play_icon.save(play_icon_path, "PNG", optimize=True)
    print(f"Generated Google Play Icon: {play_icon_path}")

    # 2. Apple App Store 아이콘: 1024x1024 (알파 채널 절대 불허 - RGB)
    app_icon_path = os.path.join(OUTPUT_DIR, "appstore_icon_1024.png")
    app_icon = icon_src.resize((1024, 1024), Image.Resampling.LANCZOS).convert("RGB")
    app_icon.save(app_icon_path, "PNG", optimize=True)
    print(f"Generated App Store Icon: {app_icon_path}")


def generate_playstore_feature_graphic():
    # 1024 x 500 px
    w, h = 1024, 500
    top_bg = (255, 250, 242, 255)
    bot_bg = (248, 230, 214, 255)
    canvas = create_linear_gradient(w, h, top_bg, bot_bg)
    draw = ImageDraw.Draw(canvas)

    # 아이콘 배치 (좌측 또는 중앙 우측)
    icon_src_path = os.path.join(BASE_DIR, "assets", "icon", "app_icon.png")
    icon_src = Image.open(icon_src_path).convert("RGBA")
    icon_size = 260
    icon_resized = icon_src.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

    # 아이콘 라운딩 마스크
    mask = create_rounded_mask((icon_size, icon_size), 54)
    rounded_icon = Image.new("RGBA", (icon_size, icon_size))
    rounded_icon.paste(icon_resized, (0, 0), mask)

    # 아이콘 그림자
    shadow = Image.new("RGBA", (icon_size + 40, icon_size + 40), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle([(20, 20), (icon_size + 20, icon_size + 20)], radius=54, fill=(0, 0, 0, 50))
    shadow = shadow.filter(ImageFilter.GaussianBlur(15))

    icon_x = 90
    icon_y = (h - icon_size) // 2
    canvas.paste(shadow, (icon_x - 20, icon_y - 10), shadow)
    canvas.paste(rounded_icon, (icon_x, icon_y), rounded_icon)

    # 텍스트 영역 (우측)
    text_x = icon_x + icon_size + 70
    title_font = get_font(46, "bold")
    sub_font = get_font(26, "semi")
    desc_font = get_font(21, "regular")

    draw.text((text_x, 140), "마음까지 전하는 AI 말벗 비서", fill=(255, 126, 54), font=sub_font)
    draw.text((text_x, 185), "시니어를 위한 다정한 대화", fill=(24, 24, 27), font=title_font)
    draw.text((text_x, 260), "말씀만 하세요, 자녀처럼 따뜻하게 대답하고\n매일의 소중한 일상을 달력에 기록해 드립니다.", fill=(90, 90, 95), font=desc_font)

    # 저장 (Google Play Feature Graphic은 RGB/24비트 PNG 또는 JPG)
    out_path = os.path.join(OUTPUT_DIR, "feature_graphic_1024x500.png")
    canvas.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"Generated Feature Graphic: {out_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=== 1. 스토어 아이콘 생성 ===")
    generate_store_icons()

    print("\n=== 2. Google Play 그래픽 이미지(Feature Graphic) 생성 ===")
    generate_playstore_feature_graphic()

    print("\n=== 3. 스토어 규격 스크린샷 4종 생성 ===")
    screens = [
        {
            "img": os.path.join(BRAIN_DIR, "screen_main_final_idle.png"),
            "title": "시니어를 위한 따뜻한 AI 음성 비서",
            "subtitle": "크고 선명한 글씨와 친절한 음성으로 대화하세요",
            "name": "01_main_home",
        },
        {
            "img": os.path.join(BRAIN_DIR, "screen_main_recording_state.png"),
            "title": "타이핑 없이 말씀만 하시면 됩니다",
            "subtitle": "버튼 하나 누르고 자녀와 통화하듯 편안하게 대화하세요",
            "name": "02_voice_input",
        },
        {
            "img": os.path.join(BRAIN_DIR, "screen_detail_voice_chat.png"),
            "title": "가족과 나누듯 정다운 일상 이야기",
            "subtitle": "오늘 있었던 일, 건강, 고민을 다정하게 들어드립니다",
            "name": "03_conversation_detail",
        },
        {
            "img": os.path.join(BRAIN_DIR, "screen_calendar_compact_verified.png"),
            "title": "달력으로 모아보는 우리 가족 추억",
            "subtitle": "매일 나눈 대화 기록이 따뜻한 일기로 보관됩니다",
            "name": "04_calendar_memories",
        },
    ]

    # iOS 6.7인치 (1290 x 2796)
    ios_dir = os.path.join(OUTPUT_DIR, "screenshots", "ios_6.7_inch")
    for s in screens:
        out = os.path.join(ios_dir, f"{s['name']}.png")
        generate_screenshot(1290, 2796, s["img"], s["title"], s["subtitle"], out, is_ios=True)

    # Android Phone (1080 x 2400)
    android_dir = os.path.join(OUTPUT_DIR, "screenshots", "android_phone")
    for s in screens:
        out = os.path.join(android_dir, f"{s['name']}.png")
        generate_screenshot(1080, 2400, s["img"], s["title"], s["subtitle"], out, is_ios=False)

    print("\n[성공] 모든 스토어 그래픽 자산이 규격에 맞게 완벽히 생성되었습니다.")


if __name__ == "__main__":
    main()
