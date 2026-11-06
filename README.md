# 圣剑英雄传之英雄救美

## 介绍

　　美丽的公主被大魔王抓走了，并限国王三天内交出王位，否则就要杀死公主；现在只有你小飞刀能救出公主，赶快行动吧……
　　《圣剑英雄传Ｉ－英雄救美》是成都金点工作组制作的中文ＲＰＧ游戏“圣剑英雄传系列”的第一辑。虽然很短小，但是她拥有自己完整的程序框架和故事情节，而且其最大的特点就是开放性，包括情节、图片、对话、程序……总之，游戏中的一切都是向大家公开的。
　　我们希望这样做能给那些正致力于游戏制作的朋友一些帮助，同时也能促进我们自身水平的提高，在此感谢各位朋友的支持！

穿越时空，经典无限。

<https://web.archive.org/web/20010409092144/http://www.gpgame.com/gpsoft/hero/hero.htm>

## 在线游玩

<https://jiangbo.online/game/sjyxz/index.html>

## 系统字体

游戏使用系统字体显示文字，不随游戏附带字体。Windows 使用 DirectWrite，
macOS 使用 Core Text，Linux 使用 Fontconfig 和 FreeType。实际运行还取决于
系统版本、图形驱动及其他运行库。

Linux 需要 Fontconfig、FreeType 和支持简体中文的字体。可以用以下命令安装：

```sh
# Debian / Ubuntu
sudo apt install libfontconfig1 libfreetype6 fonts-noto-cjk

# Fedora
sudo dnf install fontconfig freetype google-noto-sans-cjk-fonts

# Arch Linux
sudo pacman -S fontconfig freetype2 noto-fonts-cjk
```

程序由 Fontconfig 选择字体；安装后仍显示方框时，可以用以下命令查看匹配结果：

```sh
fc-match 'sans-serif:lang=zh-cn'
```

## 构建

使用 Zig 0.17 开发版，依赖的引擎版本固定在 `build.zig.zon` 中。
仓库已包含生成好的运行资源，可以直接构建和运行：

```sh
zig build
zig build run
```

Linux 构建需要 ALSA、OpenGL、X11、Fontconfig 和 FreeType 的开发库；
运行时也需要 Fontconfig 和 FreeType。原始素材在 `raw-assets`，运行资源在
`assets`。修改原始素材后，可以重新生成：

```sh
zig build atlas
zig build audio
```

音频转换需要 `ffmpeg`，工具须在 PATH 中。
