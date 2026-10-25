const zhu = @import("zhu");

const input = @import("../zon.zig").input;
const Popup = @import("shared.zig").Popup;

pub const Request = enum {
    status,
    item,
    load,
    save,
    about,
    exit,
    close,
};

var menu: zhu.extend.widget.Menu = @import("pause.zon");

// 打开暂停菜单时将光标重置回第一项。
pub fn open() Popup {
    menu.reset();
    // 没有键盘时，将暂停菜单放到游戏画面中央。
    if (zhu.key.mayNotHave) menu.centerInWindow();
    return .pause;
}

pub fn update() ?Request {
    if (input.anyReleased(&.{ .menu, .cancel })) {
        return .close;
    }

    return menu.updateEnum(Request, .{});
}

pub fn draw() void {
    menu.draw();
}
