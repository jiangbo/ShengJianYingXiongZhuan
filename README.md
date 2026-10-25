# 圣剑英雄传之英雄救美

## 介绍

　　美丽的公主被大魔王抓走了，并限国王三天内交出王位，否则就要杀死公主；现在只有你小飞刀能救出公主，赶快行动吧……
　　《圣剑英雄传Ｉ－英雄救美》是成都金点工作组制作的中文ＲＰＧ游戏“圣剑英雄传系列”的第一辑。虽然很短小，但是她拥有自己完整的程序框架和故事情节，而且其最大的特点就是开放性，包括情节、图片、对话、程序……总之，游戏中的一切都是向大家公开的。
　　我们希望这样做能给那些正致力于游戏制作的朋友一些帮助，同时也能促进我们自身水平的提高，在此感谢各位朋友的支持！

穿越时空，经典无限。

<https://web.archive.org/web/20010409092144/http://www.gpgame.com/gpsoft/hero/hero.htm>

## 在线游玩

<https://jiangbo.online/game/sjyxz/index.html>

## 构建

使用 Zig 0.17 开发版，依赖的引擎版本固定在 `build.zig.zon` 中。
字体原文件使用 Git LFS 管理。安装 Git LFS 后，拉取字体并构建：

```sh
git lfs install
git lfs pull
zig build
zig build run
```

Linux 构建需要 ALSA、OpenGL 和 X11 的开发库。
运行资源在 `assets`，原始素材在 `raw-assets`，生成的字体数据在
`src/zon/font.zon`，这些文件均随仓库提交。

修改原始素材后，可按需重新生成资源：

```sh
zig build atlas
zig build msdf
zig build audio
```

字体和音频生成分别需要 `msdf-atlas-gen` 和 `ffmpeg`，工具须在 PATH 中。
`0.1.0` 标签保留迁移前的项目版本。
