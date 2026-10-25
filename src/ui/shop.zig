const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const item = @import("item.zig");
const Popup = @import("shared.zig").Popup;

const Dialog = component.dialog.Dialog;
const Tip = component.event.Tip;

pub const Kind = enum { weapon, potion };

const Shop = struct {
    items: [16]?zon.Item.Key,
    notBoughtDialogue: u16,
    boughtDialogue: u16,
};

var index: u8 = 0; // 当前选择的商品。
var bought = false; // 本次购物是否买到过物品。
var current: *const Shop = undefined; // 当前打开的商店配置。

// 打开指定商店并从第一个商品开始选择。
pub fn open(kind: Kind) Popup {
    index = 0;
    bought = false;
    current = switch (kind) {
        .weapon => &weaponShop,
        .potion => &potionShop,
    };
    return .shop;
}

// 处理商品选择、购买和关闭操作。
pub fn update(world: *ecs.World) bool {
    if (zon.input.anyReleased(&.{ .menu, .cancel })) {
        const dialogueId = if (bought)
            current.boughtDialogue
        else
            current.notBoughtDialogue;
        world.addResource(Dialog{
            .lines = zon.dialogues[dialogueId].lines,
        });
        return true;
    }

    index = item.update(current.items.len, index);

    if (!zon.input.released(.buyItem)) return false;
    const key = current.items[index] orelse return false;
    if (buy(world, key)) bought = true;
    return false;
}

fn buy(world: *ecs.World, key: zon.Item.Key) bool {
    const inventory = world.getResourcePtr(storage.Inventory).?;
    const product = zon.Item.get(key);

    if (product.money > inventory.money) {
        world.addEvent(Tip{ .text = "兄弟，你的钱不够！" });
        return false;
    }

    if (!inventory.add(key)) {
        world.addEvent(Tip{ .text = "你已经带满了！" });
        return false;
    }

    inventory.money -= product.money;
    return true;
}

pub fn draw(world: *ecs.World) void {
    const inventory = world.getResourcePtr(storage.Inventory).?;
    const pos = item.position;
    item.draw(&current.items, index);

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    var buffer: [20]u8 = undefined;
    zhu.text.draw("（金=", pos.addXY(10, 270), .{});
    const money = zhu.format(&buffer, "{d}）", .{inventory.money});
    zhu.text.draw(money, pos.addXY(60, 270), .{});
    zhu.text.draw("CTRL=购买　　ESC=退出", pos.addXY(118, 270), .{});
}

const weaponShop: Shop = .{
    .items = .{
        .biShou,          .biShou,
        .ningShuangJian,  .ningShuangJian,
        .guWenMingKuiJia, .guWenMingKuiJia,
        .changQuanQuanPu, .changQuanQuanPu,
        .zhongJian,       .zhongJian,
        .fenKuLou,        .fenKuLou,
        .piJia,           .piJia,
        null,             null,
    },
    .notBoughtDialogue = 18,
    .boughtDialogue = 19,
};

const potionShop: Shop = .{
    .items = .{
        .huaMoGu,       .huaMoGu,
        .zhiXueCao,     .zhiXueCao,
        .huanHunCao,    .huanHunCao,
        .hongMeiGui,    .hongMeiGui,
        .hongSeYaoPing, .hongSeYaoPing,
        .yaoPing,       .yaoPing,
        null,           null,
        null,           null,
    },
    .notBoughtDialogue = 22,
    .boughtDialogue = 23,
};
