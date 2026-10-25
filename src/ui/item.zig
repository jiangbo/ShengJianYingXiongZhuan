const zhu = @import("zhu");

const zon = @import("../zon.zig");

pub const position: zhu.Vector2 = .xy(120, 90);

var texture: zhu.Image = undefined;
var background: zhu.Image = undefined;

pub fn init() void {
    texture = zhu.getImage("goods.png").?;
    background = zhu.getImage("sbar.png").?;
}

// 根据方向操作更新物品格子的选择位置。
pub fn update(len: u8, index: u8) u8 {
    var next = index;

    if (zon.input.released(.left)) {
        next = (next + len - 1) % len;
    }

    if (zon.input.released(.right)) {
        next = (next + 1) % len;
    }

    if (zon.input.released(.down)) {
        next = (next + len / 2) % len;
    }

    if (zon.input.released(.up)) {
        next = (next + len / 2 * 3) % len;
    }
    return next;
}

// 绘制商店、出售和背包共用的物品详情与格子。
pub fn draw(items: []const ?zon.Item.Key, index: usize) void {
    zhu.batch.drawImage(background, position.addXY(-10, -10), .{});

    // 绘制当前选中物品的详情。
    var buffer: [32]u8 = undefined;
    if (items[index]) |key| {
        const item = zon.Item.get(key);
        zhu.text.msdf.begin();

        zhu.text.draw(item.name, position.addXY(70, 20), .{});
        zhu.text.draw(" (价值：", position.addXY(180, 20), .{});
        const text = zhu.format(&buffer, "{d}）", .{item.money});
        zhu.text.draw(text, position.addXY(260, 20), .{});

        zhu.text.draw("经验：", position.addXY(20, 60), .{});
        zhu.text.drawNumber(item.exp, position.addXY(100, 60), .{});

        zhu.text.draw("生命：", position.addXY(20, 86), .{});
        zhu.text.drawNumber(item.health, position.addXY(100, 86), .{});

        zhu.text.draw("攻击：", position.addXY(20, 112), .{});
        zhu.text.drawNumber(item.attack, position.addXY(100, 112), .{});

        zhu.text.draw("防御：", position.addXY(20, 134), .{});
        zhu.text.drawNumber(item.defend, position.addXY(100, 134), .{});

        zhu.text.draw(item.about, position.addXY(170, 60), .{
            .color = .yellow,
        });
        zhu.text.msdf.end();
    }

    const itemBackground = getIcon(0);
    const itemSelected = getIcon(1);
    const offset = position.addXY(5, 170);

    for (0..2) |i| {
        const row: f32 = @floatFromInt(i);
        for (0..8) |j| {
            const col: f32 = @floatFromInt(j);
            const itemPos = offset.addXY(col * 49, row * 49);
            zhu.batch.drawImage(itemBackground, itemPos, .{});

            const itemIndex = j + 8 * i;
            if (items[itemIndex]) |key| {
                const icon = getIcon(zon.Item.get(key).icon);
                zhu.batch.drawImage(icon, itemPos, .{});
            }
            if (index == itemIndex) {
                zhu.batch.drawImage(itemSelected, itemPos, .{});
            }
        }
    }
}

fn getIcon(icon: usize) zhu.Image {
    const row: f32 = @floatFromInt(icon / 8);
    const col: f32 = @floatFromInt(icon % 8);
    const pos = zhu.Vector2.xy(col * 48, row * 48);
    return texture.sub(.init(pos, .xy(48, 48)));
}
