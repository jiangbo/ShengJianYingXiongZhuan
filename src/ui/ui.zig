const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");
const about = @import("about.zig");
const touch = zhu.extend.touch;
const dialog = @import("dialog.zig");
const inventory = @import("inventory.zig");
const item = @import("item.zig");
const pause = @import("pause.zig");
const sale = @import("sale.zig");
const save = @import("save.zig");
const Popup = @import("shared.zig").Popup;
const shop = @import("shop.zig");
const status = @import("status.zig");
const story = @import("story.zig");
const tip = @import("tip.zig");

const Dialog = component.dialog.Dialog;

pub const Request = union(enum) {
    block,
    battle,
    load: u8,
    save: u8,
    title,
};

var popup: ?Popup = null;

pub fn init() void {
    about.init();
    dialog.init();
    item.init();
    status.init();
}

pub fn reset() void {
    popup = null;
    story.reset();
    tip.reset();
}

pub fn update(world: *ecs.World, delta: f32) ?Request {
    // 保留默认按钮，仅按弹窗用途修改功能键。
    if (popup) |current| {
        touch.patch(.back);
        if (current == .inventory) {
            touch.patch(.init(.extra, .G, "丢弃"));
        }
    }
    touch.update();
    if (story.isOpen()) {
        const request = story.update(delta) orelse return .block;
        return switch (request) {
            .close => .block,
            .title => .title,
        };
    }

    tip.update(world, delta);
    if (updateDialog(world)) |request| return request;
    if (world.getResourcePtr(Dialog) != null) return .block;

    if (popup == null) {
        if (zon.input.anyReleased(&.{ .menu, .cancel })) {
            popup = pause.open();
            return .block;
        }
        return null;
    }

    return updatePopup(world, delta);
}

fn updateDialog(world: *ecs.World) ?Request {
    const event = dialog.update(world) orelse return null;
    switch (event) {
        .finish => {},
        .openWeaponShop => popup = shop.open(.weapon),
        .openPotionShop => popup = shop.open(.potion),
        .openSale => popup = sale.open(),
        .battle => return .battle,
        .unlock => return null,
        .showSwordTip => story.open(.sword),
        .showEnding => story.open(.ending),
    }
    return .block;
}

fn updatePopup(world: *ecs.World, delta: f32) Request {
    switch (popup.?) {
        .pause => {
            const req = pause.update() orelse return .block;
            switch (req) {
                .status => popup = .status,
                .item => popup = inventory.open(),
                .load => popup = save.open(.load),
                .save => popup = save.open(.save),
                .about => popup = about.open(),
                .exit => zhu.window.exit(),
                .close => popup = null,
            }
        },
        .about => if (about.update(delta)) {
            popup = .pause;
        },
        .save => {
            const req = save.update() orelse return .block;
            switch (req) {
                .close => popup = .pause,
                .load => |slot| {
                    popup = .pause;
                    return .{ .load = slot };
                },
                .save => |slot| {
                    popup = .pause;
                    return .{ .save = slot };
                },
            }
        },
        .status => if (status.update()) {
            popup = .pause;
        },
        .inventory => if (inventory.update(world)) |req| {
            switch (req) {
                .close => popup = .pause,
                .used => {},
            }
        },
        .sale => if (sale.update(world)) {
            popup = null;
        },
        .shop => if (shop.update(world)) {
            popup = null;
        },
    }
    return .block;
}

pub fn draw(world: *ecs.World) void {
    zhu.camera.push(.window);
    defer zhu.camera.pop();

    dialog.draw(world);
    if (popup) |current| switch (current) {
        .about => about.draw(),
        .pause => pause.draw(),
        .save => save.draw(),
        .status => status.draw(world),
        .inventory => inventory.draw(world),
        .sale => sale.draw(world),
        .shop => shop.draw(world),
    };
    tip.draw();
    story.draw();
}
