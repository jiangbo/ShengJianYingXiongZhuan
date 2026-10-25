const zhu = @import("zhu");

const zon = @import("../zon.zig");
const Typing = @import("shared.zig").Typing;

pub const Kind = enum { sword, ending };

pub const Request = enum { close, title };

const swordText =
    "　　太好了！终于找到了失落已久的“圣剑”，就用它的威力把大魔王彻底杀死吧！　";
const endingText =
    \\　　祝贺你成功打爆试玩版！详细情况请看Readme.txt
    \\敬请关注该游戏的最新动态：
    \\　　http://goldpoint.126.com
    \\　　　　　　　　　　　　　成都金点工作组制作
    \\　　　　　　　　　　　　　[THE END]
;

var current: ?Kind = null; // 当前显示的剧情文字。
var storyTyping: Typing = undefined; // 当前剧情文字的逐字显示状态。

pub fn reset() void {
    current = null;
}

// 打开指定的剧情文字。
pub fn open(next: Kind) void {
    current = next;
    storyTyping = .{
        .content = switch (next) {
            .sword => swordText,
            .ending => endingText,
        },
    };
}

pub fn isOpen() bool {
    return current != null;
}

// 文字显示完成后处理确认操作。
pub fn update(delta: f32) ?Request {
    if (storyTyping.index != storyTyping.content.len) {
        storyTyping.update(delta);
        return null;
    }
    if (!zon.input.released(.confirm) and
        !zhu.key.released(.MOUSE_LEFT)) return null;

    // 剧情结束后统一清理当前状态，不依赖各分支各自清理。
    defer current = null;
    return switch (current.?) {
        .sword => .close,
        .ending => .title,
    };
}

pub fn draw() void {
    const kind = current orelse return;
    const color: zhu.Color = switch (kind) {
        .sword => .white,
        .ending => .red,
    };

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(storyTyping.text(), .xy(80, 100), .{
        .max = 450,
        .color = color,
    });
}
