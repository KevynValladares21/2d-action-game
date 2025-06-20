# 2D Action Game (Godot 4)

A minimal 2D action game built in [Godot Engine 4.x](https://godotengine.org/).  
This is a personal side project focused on building a basic combat loop, featuring sprite-based characters, movement, attacks, and health management.

---

## 🎮 Features (MVP)

- Player character with basic movement
- One enemy type with contact or attack damage
- Basic melee attack for the player
- Health bars for both player and enemy
- Single scene test level using tilemaps and a background

---

## 🛠️ Project Setup

1. Clone the repo:
   ```bash
   git clone git@github.com:KevynValladares21/2d-action-game.git
   ```

2. Add the assets/ folder:

    You can download or create your own assets. For now, I’m using placeholder assets from Penusbmic's itch.io page (https://penusbmic.itch.io/).

    Place your sprites, sounds, and other game assets into an assets/ folder in the root of the project.

    Note: Replace the placeholder assets with your own as needed.

3. Open the project in Godot 4.x (tested with Flatpak build).

4. Run the `title-screen.tscn` scene to test gameplay.

---

## 📁 Folder Structure

```
assets/      # Sprites, sounds, raw assets
player/      # Player scene + scripts
enemies/     # Enemy scenes + scripts
tiles/       # Tilemaps and level scenes
backgrounds/ # Parallax or static backgrounds
ui/          # HUD elements like health bars
scenes/      # Main scene(s), menus, etc.
```

---

## 💡 Notes

- Art assets are placeholder sprites (purchased/royalty-free). Credit goes to Penusbmic on itch.io (https://penusbmic.itch.io/)
- This project is primarily for learning and prototyping.
- Export targets: desktop first; mobile/web maybe later.

---

## 📜 License

This project is for personal use and not currently licensed for distribution.  
If reusing code or assets, check license terms for included art/audio.

---

🔗 [View the GitHub Repository](https://github.com/KevynValladares21/2d-action-game)
