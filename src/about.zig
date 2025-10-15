const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

var texture: gfx.Texture = undefined;

pub var roll: bool = false;
var timer: window.Timer = .init(0.05);

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/sbar.png", .init(420, 320));
}

pub fn update(delta: f32) void {
    if (!roll) return;

    if (timer.isFinishedAfterUpdate(delta)) {
        if (end) return;
        timer.restart();
        rollOffset += 1;
    }
}

pub fn draw() void {
    const position = gfx.Vector.init(120, 90);
    camera.draw(texture, position.addXY(-10, -10));

    if (roll) return drawRoll(position);

    var text: []const u8 = "圣剑英雄传--英雄救美（测试版）";
    camera.drawColorText(text, position.addXY(62, 17), .{ .w = 1 });
    camera.drawText(text, position.addXY(60, 15));

    text =
        \\　　这是我们的第一个RPG游戏，本来只是
        \\想练一练手而已，不过做到一半时才发现自
        \\己错了：既然做了就应该把它做好！
        \\　　现今，国内游戏界还普遍存在着急功近
        \\利、粗制滥造的现象，希望制作者们用实际
        \\行动来改变它吧！我们的宗旨是“不求极品，
        \\但求精品！”;
    ;
    camera.drawColorText(text, position.addXY(25, 52), .{ .w = 1 });
    camera.drawText(text, position.addXY(23, 50));

    text =
        \\成都金点工作组 E-mail: wj77@163.net
        \\　　网站 http://goldpoint.126.com
    ;

    camera.drawColorText(text, position.addXY(25, 248), .{ .w = 1 });
    camera.drawText(text, position.addXY(23, 246));
}

const intro =
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\　　　　《圣剑英雄传》制作群
    \\
    \\　　《英雄救美》是一款微型的中文RPG
    \\游戏，由成都金点工作组成员 softboy
    \\和 EVA编写，游戏中出现的图片主要由网
    \\友 qinyong、 Daimy和cuigod提供。
    \\这是一个自由游戏软件，你可以任意复制
    \\并传播。如果愿意还可以自由更改，我们
    \\提供源程序。
    \\
    \\　　　　====游戏运行要求====：
    \\
    \\主机：INTEL兼容芯片，奔腾100以上CPU
    \\内存：8 兆以上
    \\显卡：SVGA 640*480*256
    \\声卡：WINDOWS 95兼容卡（可选）
    \\控制：键盘
    \\平台：WIN 95／98 + DirectX 5.0
    \\
    \\　　　　======键盘定义======：
    \\
    \\上、下、左、右 ---------- 行走
    \\　　　　　Ctrl ---------- 对话
    \\　　　　Enter  ---------- 确认
    \\　　　　Escape ---------- 调主菜单
    \\
    \\        ======文件清单======：
    \\
    \\  rpg.exe--------主程序
    \\  readme.txt-----说明/帮助
    \\  log.txt--------游戏制作日志
    \\  maps\*.*-------地图数据/NPC数据
    \\  pic\*.*--------游戏中使用的图片
    \\  text\*.*-------对白/物品数据
    \\  voc\*.*--------声音
    \\
    \\   最后，祝大家快乐！
    \\
    \\        敬礼！
    \\
    \\    =========制作成员=========：
    \\
    \\softboy -- 程序     wj77@163.net
    \\李为EVA -- 美工     eva@188.net
    \\qinyong -- 图片提供 qinyong@163.net
    \\  daimy -- 图片提供 daimy@163.net
    \\ cuigod -- 图片提供 cuiin@263.net
    \\   孔雀 -- 剧情支持 kclamp@21cn.com
    \\
    \\    =========联系方法=========
    \\
    \\汪疆(softboy)
    \\Mail:wj77@163.net
    \\主页:http://goldpoint.126.com
    \\ Tel:(028-4318564)
    \\成都电子科技大学 95080-5 [610054]
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\
    \\　　　　　　成都金点工作组
    \\　　　　　　一九九九年六月
    \\
    \\
    \\
    \\
    \\
;

var rollOffset: usize = 0;
const lineHeight = 26;
var start: usize = 0;
var end: bool = false;

pub fn resetRoll() void {
    roll = false;
    rollOffset = 0;
    end = false;
    timer.reset();
}

fn drawRoll(position: gfx.Vector) void {
    defer camera.resetScissor();

    const size = gfx.Vector.init(380, 280);
    camera.scissor(.init(position.addXY(20, 12), size));

    const offsetY: f32 = @floatFromInt(rollOffset % lineHeight);

    if (end) {
        camera.drawText(intro[start..], position.addXY(25, -offsetY));
        return;
    }

    const startLine = rollOffset / lineHeight;
    var line: u8 = 0;

    var iter = std.unicode.Utf8View.initUnchecked(intro).iterator();
    if (startLine == 0)
        line = 0
    else while (iter.nextCodepoint()) |unicode| {
        if (unicode != '\n') continue;
        line += 1;
        if (line >= startLine) break;
    }

    start = iter.i;
    while (iter.nextCodepoint()) |unicode| {
        if (unicode != '\n') continue;
        line += 1;
        if (line >= startLine + 12) break;
    } else end = true;

    camera.drawText(intro[start..iter.i], position.addXY(25, -offsetY));
}
