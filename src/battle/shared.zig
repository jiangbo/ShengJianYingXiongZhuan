const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("../zon.zig");

pub const attackSounds: [3][:0]const u8 = .{
    "audio/ack_00.ogg",
    "audio/ack_01.ogg",
    "audio/ack_02.ogg",
};

pub const hurtSounds: [3][:0]const u8 = .{
    "audio/ao_00.ogg",
    "audio/ao_01.ogg",
    "audio/ao_02.ogg",
};

pub const deadSounds: [3][:0]const u8 = .{
    "audio/dead_00.ogg",
    "audio/dead_01.ogg",
    "audio/dead_02.ogg",
};

pub const enemySounds: [15]u8 = .{
    2, 1, 2, 2, 1,
    2, 1, 1, 2, 1,
    1, 1, 1, 1, 2,
};

// 双方阶段通过该标识返回下一阶段。
pub const Phase = enum {
    menu,
    playerAttack,
    enemyHurt,
    wait,
    enemyAttack,
    playerHurt,
    playerDeath,
    enemyDeath,
    status,
    item,
    win,
    escape,
    title,
};

pub var menu: zhu.extend.widget.Menu = @import("battle.zon");

pub const Menu = struct {
    const Command = enum { attack, status, item, escape };
    // 仅在菜单阶段处理战斗指令。
    pub fn update(_: *ecs.World, _: f32) ?Phase {
        switch (menu.updateEnum(Command, .{}) orelse return null) {
            .attack => return .playerAttack,
            .status => return .status,
            .item => return .item,
            .escape => {
                const escape = zhu.random.int(u8, 0, 100);
                if (enemy.escape > escape) return .escape;

                return wait(.enemyAttack, "逃跑失败！");
            },
        }
    }
};

// 当前敌人的稳定标识和可变数据副本。
pub var enemyKey: zon.Actor.Key = undefined;
pub var enemy: zon.Actor = undefined;

pub var bombAnimation: zhu.Animation = undefined;

// 根据攻击和防御计算本次伤害。
pub fn computeDamage(attack: u16, defend: u16) u16 {
    var damage = attack * 2 -| defend;

    if (damage <= 10) {
        damage = zhu.random.intBiased(u16, 0, 10);
    } else {
        damage += zhu.random.intBiased(u16, 0, damage);
    }
    return damage;
}

// 设置等待结束后的阶段和提示，并返回等待阶段。
pub fn wait(next: Phase, tip: []const u8) Phase {
    Wait.next = next;
    Wait.tip = tip;
    return .wait;
}

pub const Wait = struct {
    var timer: zhu.Timer = .init(0.5);
    var next: Phase = .menu;
    var tip: []const u8 = &.{};

    // 重新开始阶段等待。
    pub fn enter(_: *ecs.World) void {
        timer.restart();
    }

    // 等待结束后返回预先设置的阶段。
    pub fn update(_: *ecs.World, delta: f32) ?Phase {
        return if (timer.updateFinished(delta)) next else null;
    }

    // 绘制等待期间的临时提示。
    pub fn draw(_: *ecs.World) void {
        if (tip.len == 0) return;

        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(tip, .xy(290, 210), .{});
    }
};
