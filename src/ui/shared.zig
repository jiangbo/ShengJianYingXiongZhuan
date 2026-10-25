const zhu = @import("zhu");

// UI 弹出界面标识。
pub const Popup = enum {
    about,
    inventory,
    pause,
    sale,
    save,
    shop,
    status,
};

// 逐字显示文字的状态。
pub const Typing = struct {
    content: []const u8, // 完整文字。
    index: usize = 0, // 当前显示到的字节位置。
    timer: zhu.Timer = .init(0.08), // 每个字符的显示间隔。

    // 从头开始显示当前文字。
    pub fn reset(self: *Typing) void {
        self.index = 0;
        self.timer.restart();
    }

    // 到达显示间隔后推进一个 UTF-8 字符。
    pub fn update(self: *Typing, delta: f32) void {
        if (self.index == self.content.len) return;
        if (!self.timer.updateFinished(delta)) return;

        self.index = zhu.text.nextIndex(self.content, self.index);
        self.timer.restart();
    }

    // 返回当前已经显示的文字。
    pub fn text(self: *const Typing) []const u8 {
        return self.content[0..self.index];
    }
};
