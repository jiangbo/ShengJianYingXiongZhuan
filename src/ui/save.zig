const zhu = @import("zhu");

const storage = @import("../storage.zig");
const Popup = @import("shared.zig").Popup;

pub const Mode = enum { load, save };
pub const Request = union(enum) { close, load: u8, save: u8 };

var mode: Mode = .load;
var menu: zhu.extend.widget.Menu = @import("save.zon");

// 打开指定用途的存档槽菜单。
pub fn open(next: Mode) Popup {
    mode = next;
    menu.reset();
    // 没有键盘时，将存档面板放到游戏画面中央。
    if (zhu.key.mayNotHave) menu.centerInWindow();
    return .save;
}

pub fn update() ?Request {
    const event = menu.update(.{}) orelse return null;
    if (event == 6) return .close;

    const slot: u8 = @intCast(event);
    if (mode == .load and !storage.exists(slot)) return null;
    return switch (mode) {
        .load => .{ .load = slot },
        .save => .{ .save = slot },
    };
}

pub fn draw() void {
    menu.draw();
}
