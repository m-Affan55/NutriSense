import os
from PIL import Image, ImageDraw

def create_icons():
    icons_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "icons"))
    os.makedirs(icons_dir, exist_ok=True)

    # High-resolution canvas for super-sampling (256x256 resized to 128x128)
    def get_canvas():
        return Image.new("RGBA", (256, 256), (0, 0, 0, 0))

    def save_icon(img, name):
        img_resized = img.resize((128, 128), Image.Resampling.LANCZOS)
        path = os.path.join(icons_dir, f"{name}.png")
        img_resized.save(path, "PNG")
        return path

    # Colors (RGBA)
    EMERALD = (52, 211, 153, 255)  # #34d399
    CYAN = (34, 211, 238, 255)     # #22d3ee
    AMBER = (251, 191, 36, 255)    # #fbbf24
    CORAL = (248, 113, 113, 255)   # #f87171
    WHITE = (248, 250, 252, 255)

    # 1. Camera / Vision (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([30, 70, 226, 210], radius=24, outline=EMERALD, width=12)
    d.polygon([(70, 70), (90, 40), (166, 40), (186, 70)], outline=EMERALD, fill=None)
    d.line([(70, 70), (90, 40), (166, 40), (186, 70)], fill=EMERALD, width=12)
    d.ellipse([92, 104, 164, 176], outline=EMERALD, width=12)
    d.ellipse([185, 95, 200, 110], fill=EMERALD)
    save_icon(img, "camera_emerald")

    # 2. Shield / Safety (Coral)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    points = [(128, 30), (210, 60), (210, 140), (128, 226), (46, 140), (46, 60)]
    d.polygon(points, outline=CORAL, width=12)
    # Checkmark inside
    d.line([(85, 128), (115, 158), (175, 95)], fill=CORAL, width=14)
    save_icon(img, "shield_coral")

    # 3. Moon / Ramadan (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.chord([40, 40, 216, 216], start=45, end=315, outline=CYAN, width=12)
    # Draw inner cutout
    d.arc([75, 40, 216, 180], start=45, end=315, fill=CYAN, width=12)
    save_icon(img, "moon_cyan")

    # 4. Users / Family (Amber)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    # Center user head & body
    d.ellipse([98, 40, 158, 100], outline=AMBER, width=12)
    d.arc([58, 120, 198, 240], start=180, end=0, fill=AMBER, width=12)
    # Left small user
    d.ellipse([40, 70, 80, 110], outline=AMBER, width=8)
    d.arc([20, 130, 100, 220], start=180, end=0, fill=AMBER, width=8)
    # Right small user
    d.ellipse([176, 70, 216, 110], outline=AMBER, width=8)
    d.arc([156, 130, 236, 220], start=180, end=0, fill=AMBER, width=8)
    save_icon(img, "users_amber")

    # 5. Heartbeat / Activity Pulse (Coral)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    pulse_pts = [(30, 130), (80, 130), (105, 50), (135, 210), (165, 95), (185, 155), (200, 130), (226, 130)]
    d.line(pulse_pts, fill=CORAL, width=14, joint="curve")
    save_icon(img, "pulse_coral")

    # 6. Food / Bowl / Curry (Amber)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.chord([40, 90, 216, 220], start=0, end=180, outline=AMBER, width=12)
    d.line([(30, 90), (226, 90)], fill=AMBER, width=12)
    # Steam lines
    d.line([(80, 35), (80, 70)], fill=AMBER, width=10)
    d.line([(128, 25), (128, 70)], fill=AMBER, width=10)
    d.line([(176, 35), (176, 70)], fill=AMBER, width=10)
    save_icon(img, "food_amber")

    # 7. Warning Triangle (Coral)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(128, 35), (226, 210), (30, 210)], outline=CORAL, width=12)
    d.line([(128, 90), (128, 145)], fill=CORAL, width=12)
    d.ellipse([122, 168, 134, 180], fill=CORAL)
    save_icon(img, "warning_coral")

    # 8. Smartphone (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([65, 30, 191, 226], radius=20, outline=CYAN, width=12)
    d.ellipse([120, 188, 136, 204], fill=CYAN)
    d.line([(100, 55), (156, 55)], fill=CYAN, width=8)
    save_icon(img, "phone_cyan")

    # 9. Stethoscope (Coral)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.arc([55, 30, 175, 150], start=0, end=180, fill=CORAL, width=12)
    d.line([(55, 30), (55, 60)], fill=CORAL, width=12)
    d.line([(175, 30), (175, 60)], fill=CORAL, width=12)
    d.line([(115, 150), (115, 190)], fill=CORAL, width=12)
    d.ellipse([185, 160, 225, 200], outline=CORAL, width=10)
    d.line([(115, 190), (185, 180)], fill=CORAL, width=10)
    save_icon(img, "stethoscope_coral")

    # 10. Users (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([98, 40, 158, 100], outline=CYAN, width=12)
    d.arc([58, 120, 198, 240], start=180, end=0, fill=CYAN, width=12)
    save_icon(img, "users_cyan")

    # 11. Portion Sliders (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.line([(40, 70), (216, 70)], fill=CYAN, width=10)
    d.ellipse([90, 50, 130, 90], fill=CYAN)
    d.line([(40, 130), (216, 130)], fill=CYAN, width=10)
    d.ellipse([150, 110, 190, 150], fill=CYAN)
    d.line([(40, 190), (216, 190)], fill=CYAN, width=10)
    d.ellipse([70, 170, 110, 210], fill=CYAN)
    save_icon(img, "sliders_cyan")

    # 12. Barcode (Amber)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    lines = [(45, 16), (75, 8), (95, 22), (130, 8), (150, 18), (180, 8), (205, 16)]
    for x, w in lines:
        d.line([(x, 40), (x, 216)], fill=AMBER, width=w)
    save_icon(img, "barcode_amber")

    # 13. Chat / NLP (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([35, 45, 221, 180], radius=24, outline=EMERALD, width=12)
    d.polygon([(65, 180), (65, 225), (115, 180)], fill=EMERALD)
    d.line([(70, 95), (186, 95)], fill=EMERALD, width=10)
    d.line([(70, 135), (146, 135)], fill=EMERALD, width=10)
    save_icon(img, "chat_emerald")

    # 14. Lightning / Zap (Coral)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(145, 25), (65, 135), (130, 135), (110, 230), (190, 115), (125, 115)], fill=CORAL)
    save_icon(img, "zap_coral")

    # 15. Map Pin / Hospital (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([78, 30, 178, 130], outline=EMERALD, width=12)
    d.polygon([(78, 90), (178, 90), (128, 226)], fill=EMERALD)
    d.ellipse([110, 62, 146, 98], fill=(10, 15, 29, 255))
    save_icon(img, "mappin_emerald")

    # 16. Dumbbell / Workout (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([30, 75, 65, 181], radius=8, fill=EMERALD)
    d.rounded_rectangle([65, 95, 80, 161], radius=6, fill=EMERALD)
    d.line([(80, 128), (176, 128)], fill=EMERALD, width=16)
    d.rounded_rectangle([176, 95, 191, 161], radius=6, fill=EMERALD)
    d.rounded_rectangle([191, 75, 226, 181], radius=8, fill=EMERALD)
    save_icon(img, "dumbbell_emerald")

    # 17. Users (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([98, 40, 158, 100], outline=EMERALD, width=12)
    d.arc([58, 120, 198, 240], start=180, end=0, fill=EMERALD, width=12)
    save_icon(img, "users_emerald")

    # 18. Mic / Audio (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([98, 30, 158, 140], radius=30, outline=CYAN, width=12)
    d.arc([68, 80, 188, 180], start=0, end=180, fill=CYAN, width=12)
    d.line([(128, 180), (128, 225)], fill=CYAN, width=12)
    d.line([(88, 225), (168, 225)], fill=CYAN, width=12)
    save_icon(img, "mic_cyan")

    # 19. Database (Amber)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([50, 35, 206, 85], outline=AMBER, width=10)
    d.line([(50, 60), (50, 190)], fill=AMBER, width=10)
    d.line([(206, 60), (206, 190)], fill=AMBER, width=10)
    d.arc([50, 95, 206, 145], start=0, end=180, fill=AMBER, width=10)
    d.arc([50, 145, 206, 195], start=0, end=180, fill=AMBER, width=10)
    d.arc([50, 165, 206, 215], start=0, end=180, fill=AMBER, width=10)
    save_icon(img, "database_amber")

    # 20. Server / FastAPI (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([35, 40, 221, 110], radius=14, outline=EMERALD, width=10)
    d.ellipse([190, 70, 205, 85], fill=EMERALD)
    d.rounded_rectangle([35, 145, 221, 215], radius=14, outline=EMERALD, width=10)
    d.ellipse([190, 175, 205, 190], fill=EMERALD)
    save_icon(img, "server_emerald")

    # 21. CPU / Gemini (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([65, 65, 191, 191], radius=18, outline=CYAN, width=12)
    d.rounded_rectangle([95, 95, 161, 161], radius=10, fill=CYAN)
    # Pins
    for p in [95, 128, 161]:
        d.line([(p, 35), (p, 65)], fill=CYAN, width=8)
        d.line([(p, 191), (p, 221)], fill=CYAN, width=8)
        d.line([(35, p), (65, p)], fill=CYAN, width=8)
        d.line([(191, p), (221, p)], fill=CYAN, width=8)
    save_icon(img, "cpu_cyan")

    # 22. Globe / Market (Emerald)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([35, 35, 221, 221], outline=EMERALD, width=12)
    d.line([(35, 128), (221, 128)], fill=EMERALD, width=10)
    d.ellipse([80, 35, 176, 221], outline=EMERALD, width=10)
    save_icon(img, "globe_emerald")

    # 23. Briefcase / Business (Cyan)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([35, 80, 221, 215], radius=16, outline=CYAN, width=12)
    d.rounded_rectangle([85, 40, 171, 80], radius=12, outline=CYAN, width=10)
    d.line([(35, 130), (221, 130)], fill=CYAN, width=10)
    d.rounded_rectangle([113, 115, 143, 145], radius=4, fill=CYAN)
    save_icon(img, "briefcase_cyan")

    # 24. Rocket / Roadmap (Amber)
    img = get_canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(128, 25), (185, 95), (185, 175), (128, 195), (71, 175), (71, 95)], outline=AMBER, width=12)
    d.ellipse([110, 90, 146, 126], fill=AMBER)
    # Fins
    d.polygon([(71, 145), (35, 185), (71, 185)], fill=AMBER)
    d.polygon([(185, 145), (221, 185), (185, 185)], fill=AMBER)
    save_icon(img, "rocket_amber")

    print(f"Generated 24 custom PNG icons in {icons_dir}")

if __name__ == "__main__":
    create_icons()
