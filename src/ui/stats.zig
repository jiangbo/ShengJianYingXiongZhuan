const zhu = @import("zhu");
const ecs = @import("ecs");

const storage = @import("../storage.zig");

// 绘制状态页和物品页共用的玩家属性。
pub fn draw(world: *ecs.World, pos: zhu.Vector2, spacing: f32) void {
    const stats = world.getResourcePtr(storage.Stats).?;
    const inventory = world.getResourcePtr(storage.Inventory).?;
    const shadow: zhu.text.Option = .{ .color = .black };
    const gold: zhu.text.Option = .{ .color = .yellow };

    var y = 22 + spacing;
    zhu.text.draw("等级：", pos.addXY(122, y), shadow);
    zhu.text.draw("等级：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.level, pos.addXY(232, y), shadow);
    zhu.text.drawNumber(stats.level, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("经验：", pos.addXY(122, y), shadow);
    zhu.text.draw("经验：", pos.addXY(120, y - 2), .{});
    var buffer: [30]u8 = undefined;
    const experience = zhu.format(&buffer, "{d}/{d}", .{
        stats.exp,
        100,
    });
    zhu.text.draw(experience, pos.addXY(232, y), shadow);
    zhu.text.draw(experience, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("生命：", pos.addXY(122, y), shadow);
    zhu.text.draw("生命：", pos.addXY(120, y - 2), .{});
    const health = zhu.format(&buffer, "{d}/{d}", .{
        stats.health,
        stats.maxHealth,
    });
    zhu.text.draw(health, pos.addXY(232, y), shadow);
    zhu.text.draw(health, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("攻击：", pos.addXY(122, y), shadow);
    zhu.text.draw("攻击：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.attack, pos.addXY(232, y), shadow);
    zhu.text.drawNumber(stats.attack, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("防御：", pos.addXY(122, y), shadow);
    zhu.text.draw("防御：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.defend, pos.addXY(232, y), shadow);
    zhu.text.drawNumber(stats.defend, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("速度：", pos.addXY(122, y), shadow);
    zhu.text.draw("速度：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.agility, pos.addXY(232, y), shadow);
    zhu.text.drawNumber(stats.agility, pos.addXY(230, y - 2), .{});

    y += spacing;
    zhu.text.draw("金币：", pos.addXY(122, y), shadow);
    zhu.text.draw("金币：", pos.addXY(120, y - 2), gold);
    zhu.text.drawNumber(inventory.money, pos.addXY(232, y), shadow);
    zhu.text.drawNumber(inventory.money, pos.addXY(230, y - 2), gold);
}
