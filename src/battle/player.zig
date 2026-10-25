const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const audio = zhu.audio;
const math = zhu.math;
const touch = zhu.extend.touch;

const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const shared = @import("shared.zig");

pub const Attack = struct {
    // 开始玩家方攻击动画。
    pub fn enter(_: *ecs.World) void {
        audio.playSound(shared.attackSounds[0]);
        shared.bombAnimation.reset();
    }

    // 攻击动画结束后进入敌方受伤阶段。
    pub fn update(_: *ecs.World, delta: f32) ?shared.Phase {
        if (shared.bombAnimation.update(delta) == .end) {
            return .enemyHurt;
        }
        return null;
    }

    // 在敌方位置绘制攻击动画。
    pub fn draw(_: *ecs.World) void {
        const image = shared.bombAnimation.subImage();
        zhu.batch.drawImage(image, .xy(452, 230), .{});
    }
};

pub const Hurt = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    // 计算玩家受到的伤害并开始受伤动画。
    pub fn enter(world: *ecs.World) void {
        audio.playSound(shared.hurtSounds[0]);

        const stats = world.getResourcePtr(storage.Stats).?;
        damage = shared.computeDamage(shared.enemy.attack, stats.defend);
        stats.health -= @intCast(damage);
        timer.restart();
        offset = 0;
    }

    // 受伤动画结束后判断玩家是否死亡。
    pub fn update(world: *ecs.World, delta: f32) ?shared.Phase {
        if (timer.updateFinished(delta)) {
            const stats = world.getResourcePtr(storage.Stats).?;
            return if (stats.health <= 0) .playerDeath else .menu;
        }

        const period: u8 = @intFromFloat(
            @trunc(timer.elapsed / 0.08),
        );
        offset = if (period % 2 == 0) -5 else 5;
        return null;
    }

    // 绘制玩家抖动和伤害数字。
    pub fn draw(_: *ecs.World) void {
        const position = math.Vector2.xy(130, 220).addX(offset);
        const image = zon.Actor.image(.player, .right);
        zhu.batch.drawImage(image, position, .{});

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(130, y), .{});
    }
};

pub const Death = struct {
    // 播放玩家死亡声音。
    pub fn enter(_: *ecs.World) void {
        audio.playSound(shared.deadSounds[0]);
    }

    // 确认键或鼠标左键松开后返回标题场景。
    pub fn update(_: *ecs.World, _: f32) ?shared.Phase {
        return if (zon.input.released(.confirm) or
            zhu.key.released(.MOUSE_LEFT)) .title else null;
    }

    // 绘制玩家死亡提示。
    pub fn draw(_: *ecs.World) void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw("你死了！", .xy(285, 200), .{});
    }
};

pub const Status = struct {
    const status = @import("../ui/status.zig");

    // 状态页关闭后返回战斗菜单。
    pub fn update(_: *ecs.World, _: f32) ?shared.Phase {
        touch.patch(.back);
        return if (status.update()) .menu else null;
    }

    // 绘制玩家状态页。
    pub fn draw(world: *ecs.World) void {
        status.draw(world);
    }
};

pub const Item = struct {
    const inventory = @import("../ui/inventory.zig");

    // 进入物品阶段时打开背包。
    pub fn enter(_: *ecs.World) void {
        _ = inventory.open();
    }

    // 处理战斗中的物品选择。
    pub fn update(world: *ecs.World, _: f32) ?shared.Phase {
        touch.patch(.back);
        touch.patch(.init(.extra, .G, "丢弃"));
        const request = inventory.update(world) orelse return null;
        return switch (request) {
            .used => .enemyAttack,
            .close => .menu,
        };
    }

    // 绘制战斗物品页。
    pub fn draw(world: *ecs.World) void {
        inventory.draw(world);
    }
};
