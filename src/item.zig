const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

pub const Item = struct {
    id: u16,
    name: []const u8 = &.{},
    about: []const u8 = &.{},
    money: u32 = 0,
    exp: i32 = 0,
    health: i32 = 0,
    attack: i32 = 0,
    defend: i32 = 0,
};

pub const Pickup = struct { itemIndex: u8, count: u8 };

pub const zon: []const Item = @import("zon/item.zon");
pub const pickupZon: []const Pickup = @import("zon/pickup.zon");
pub const position: gfx.Vector = .init(120, 90);

pub var picked: std.StaticBitSet(32) = .initEmpty();

var texture: gfx.Texture = undefined;
var bgTexture: gfx.Texture = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/goods.png", .init(384, 192));
    bgTexture = gfx.loadTexture("assets/pic/sbar.png", .init(420, 320));
}

pub fn update(len: u8, index: u8) u8 {
    var itemIndex = index;

    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        itemIndex = (itemIndex + len - 1) % len;
    }

    if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        itemIndex = (itemIndex + 1) % len;
    }

    if (window.isAnyKeyRelease(&.{ .DOWN, .S })) {
        itemIndex = (itemIndex + len / 2) % len;
    }

    if (window.isAnyKeyRelease(&.{ .UP, .W })) {
        itemIndex = (itemIndex + len / 2 * 3) % len;
    }
    return itemIndex;
}

pub fn draw(items: []const u8, itemIndex: usize) void {
    camera.draw(bgTexture, position.addXY(-10, -10));

    // 当前选中物品
    var buffer: [32]u8 = undefined;
    if (items[itemIndex] != 0) {
        const current = zon[items[itemIndex]];

        camera.drawText(current.name, position.addXY(70, 20));
        camera.drawText(" (价值：", position.addXY(180, 20));
        const text = zhu.format(&buffer, "{d}）", .{current.money});
        camera.drawText(text, position.addXY(260, 20));

        camera.drawText("经验：", position.addXY(20, 60));
        camera.drawNumber(current.exp, position.addXY(100, 60));

        camera.drawText("生命：", position.addXY(20, 86));
        camera.drawNumber(current.health, position.addXY(100, 86));

        camera.drawText("攻击：", position.addXY(20, 112));
        camera.drawNumber(current.attack, position.addXY(100, 112));

        camera.drawText("防御：", position.addXY(20, 134));
        camera.drawNumber(current.defend, position.addXY(100, 134));

        // 描述
        const color = gfx.color(1, 1, 0, 1);
        camera.drawColorText(current.about, position.addXY(170, 60), color);
    }

    const itemBg = getIconFromIndex(0);
    const itemSelected = getIconFromIndex(1);

    const offset = position.addXY(5, 170);

    for (0..2) |i| {
        const row: f32 = @floatFromInt(i);
        for (0..8) |j| {
            const col: f32 = @floatFromInt(j);
            const itemPos = offset.addXY(col * 49, row * 49);
            camera.draw(itemBg, itemPos);

            const index = j + 8 * i;
            defer if (itemIndex == index) camera.draw(itemSelected, itemPos);
            if (items[index] == 0) continue;

            camera.draw(getIconFromIndex(items[index] - 2), itemPos);
        }
    }
}

fn getIconFromIndex(index: usize) gfx.Texture {
    const row: f32 = @floatFromInt(index / 8);
    const col: f32 = @floatFromInt(index % 8);
    const pos = gfx.Vector.init(col * 48, row * 48);
    return texture.subTexture(.init(pos, .init(48, 48)));
}
