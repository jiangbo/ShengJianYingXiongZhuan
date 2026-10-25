const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const item = @import("item.zig");
const Popup = @import("shared.zig").Popup;

const Dialog = component.dialog.Dialog;
const Tip = component.event.Tip;

var index: u8 = 0; // 当前选择的背包格子。
var sold = false; // 本次出售是否卖出过物品。
var soldKey: ?zon.Item.Key = null; // 最近卖出的物品。

// 开始一次新的出售过程并从第一个格子开始选择。
pub fn open() Popup {
    index = 0;
    sold = false;
    soldKey = null;
    return .sale;
}

// 处理出售选择、卖出和关闭操作。
pub fn update(world: *ecs.World) bool {
    if (zon.input.anyReleased(&.{ .menu, .cancel })) {
        const lines = zon.dialogues[if (sold) 27 else 26].lines;
        world.addResource(Dialog{ .lines = lines });
        return true;
    }

    if (soldKey != null and zhu.input.press.released) {
        soldKey = null;
    }

    const inventory = world.getResourcePtr(storage.Inventory).?;
    index = item.update(inventory.items.len, index);

    const key = inventory.items[index] orelse return false;
    if (!zon.input.released(.useItem)) return false;

    const soldItem = zon.Item.get(key);
    inventory.money += soldItem.money / 2;
    inventory.items[index] = null;
    soldKey = key;
    sold = true;
    world.addEvent(Tip{ .text = "这东西归别人了！" });
    return false;
}

pub fn draw(world: *ecs.World) void {
    const inventory = world.getResourcePtr(storage.Inventory).?;
    const pos = item.position;
    item.draw(&inventory.items, index);

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    var buffer: [50]u8 = undefined;
    if (soldKey) |key| {
        const soldItem = zon.Item.get(key);
        const args = .{ soldItem.name, soldItem.money / 2 };
        const text = zhu.format(&buffer, "卖掉[{s}]得到：{d}", args);
        const shadowPos = pos.addXY(102, 110);
        zhu.text.draw(text, shadowPos, .{ .color = .black });
        zhu.text.draw(text, pos.addXY(100, 108), .{});
    }

    zhu.text.draw("（金=", pos.addXY(10, 270), .{});
    const money = zhu.format(&buffer, "{d}）", .{inventory.money});
    zhu.text.draw(money, pos.addXY(60, 270), .{});
    zhu.text.draw("CTRL=卖出  ESC=退出", pos.addXY(118, 270), .{});
}
