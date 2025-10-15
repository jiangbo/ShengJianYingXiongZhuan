const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;
const audio = zhu.audio;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");
const player = @import("player.zig");
const menu = @import("menu.zig");
const item = @import("item.zig");

var enemyIndex: u16 = 0;
var enemy: npc.Character = undefined;

var texture: gfx.Texture = undefined;

const bombArray: [10]gfx.Frame = blk: {
    var array: [10]gfx.Frame = undefined;
    const size = math.Vector2.init(54, 50);
    for (&array, 0..) |*value, i| {
        value.* = .{
            .area = .init(.init(@floatFromInt(54 * i), 0), size),
            .interval = 0.06,
        };
    }
    break :blk array;
};
var bombAnimation: gfx.FrameAnimation = undefined;

const attackSounds: [3][:0]const u8 = .{
    "assets/voc/ack_00.ogg",
    "assets/voc/ack_01.ogg",
    "assets/voc/ack_02.ogg",
};

const hurtSounds: [3][:0]const u8 = .{
    "assets/voc/ao_00.ogg",
    "assets/voc/ao_01.ogg",
    "assets/voc/ao_02.ogg",
};

const deadSounds: [3][:0]const u8 = .{
    "assets/voc/dead_00.ogg",
    "assets/voc/dead_01.ogg",
    "assets/voc/dead_02.ogg",
};

const enemySounds: [15]u8 = .{ 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 2 };

const Phase = union(enum) {
    menu: MenuPhase,
    playerAttack: PlayerAttackPhase,
    enemyHurt: EnemyHurtPhase,
    wait: WaitPhase,
    enemyAttack: EnemyAttackPhase,
    playerHurt: PlayerHurtPhase,
    playerDeath: PlayerDeathPhase,
    enemyDeath: EnemyDeathPhase,
    status: StatusPhase,
    item: ItemPhase,

    fn enter(self: Phase) void {
        switch (self) {
            .menu, .status, .item => {},
            inline else => |case| @TypeOf(case).enter(),
        }
    }

    fn update(self: Phase, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    fn draw(self: Phase) void {
        switch (self) {
            .menu => {},
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};
var phase: Phase = .menu;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/fightbar.png", .init(448, 112));
    const bombTexture = gfx.loadTexture("assets/pic/bomb.png", .init(540, 50));
    bombAnimation = .init(bombTexture, &bombArray);
    bombAnimation.loop = false;
}

pub fn enter() void {
    enemyIndex = context.battleNpcIndex;
    enemy = npc.zon[enemyIndex];
    map.linkIndex = 15;
    _ = map.enter();
    menu.active = 7;
    changePhase(.menu);
    camera.position = .zero;
}

pub fn exit() void {
    map.linkIndex = context.oldMapIndex;
}

fn changePhase(newPhase: Phase) void {
    phase = newPhase;
    phase.enter();
}

pub fn update(delta: f32) void {
    phase.update(delta);
}

pub fn draw() void {
    map.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    var buffer: [100]u8 = undefined;

    if (phase != .playerHurt and phase != .playerDeath) {
        // 战斗人物
        camera.draw(player.battleTexture(), .init(130, 220));
    }

    if (phase != .enemyHurt and phase != .enemyDeath) {
        // 战斗 NPC
        camera.draw(npc.battleTexture(enemyIndex), .init(465, 237));
    }

    const position = gfx.Vector.init(96, 304);

    // 状态栏背景
    camera.draw(texture, position);
    // 角色的头像
    camera.draw(player.photo(), position.addXY(10, 10));

    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        player.health,
        player.attack,
        player.defend,
        player.level,
    });
    camera.drawColorText(text, position.addXY(50, 5), .black);

    // 敌人的头像
    const npcTexture = npc.photo(context.battleNpcIndex);
    camera.draw(npcTexture, position.addXY(265, 26));

    text = zhu.format(&buffer, format, .{
        enemy.health,
        enemy.attack,
        enemy.defend,
        enemy.level,
    });
    camera.drawColorText(text, position.addXY(305, 5), .black);

    menu.draw();
    phase.draw();
}

fn computeDamage(attack: u16, defend: u16) u16 {
    var damage = attack * 2 -| defend;

    if (damage <= 10)
        damage = math.random().intRangeLessThanBiased(u16, 0, 10)
    else {
        damage += math.random().intRangeLessThanBiased(u16, 0, damage);
    }
    return damage;
}

const MenuPhase = struct {
    fn update(_: f32) void {
        const optionalEvent = menu.update();
        if (optionalEvent) |event| switch (event) {
            0 => changePhase(.playerAttack),
            1 => changePhase(.status),
            2 => changePhase(.item),
            3 => {
                if (enemy.escape > zhu.randU8(0, 100)) {
                    scene.changeScene(.world);
                } else {
                    WaitPhase.tip = "逃跑失败！";
                    WaitPhase.next = .enemyAttack;
                    changePhase(.wait);
                }
            },
            else => unreachable,
        };
    }
};

const PlayerAttackPhase = struct {
    fn enter() void {
        audio.playSound(attackSounds[0]);
        bombAnimation.reset();
    }

    fn update(delta: f32) void {
        if (bombAnimation.isFinishedAfterUpdate(delta))
            changePhase(.enemyHurt);
    }

    fn draw() void {
        camera.draw(bombAnimation.currentTexture(), .init(452, 230));
    }
};

const EnemyHurtPhase = struct {
    var damage: u16 = 0;
    var timer: window.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter() void {
        audio.playSound(hurtSounds[enemySounds[enemy.picture]]);

        damage = computeDamage(player.attack, enemy.defend);
        enemy.health -|= damage;

        timer.reset();
    }

    fn update(delta: f32) void {
        if (timer.isFinishedAfterUpdate(delta)) {
            if (enemy.health == 0) return changePhase(.enemyDeath);
            WaitPhase.next = .enemyAttack;
            return changePhase(.wait);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw() void {
        const pos = math.Vector2.init(465, 237).addX(offset);
        camera.draw(npc.battleTexture(enemyIndex), pos);

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        camera.drawText(text, .init(465, y));
    }
};

const WaitPhase = struct {
    var timer: window.Timer = .init(0.5);
    var next: Phase = .menu;
    var tip: []const u8 = &.{};

    fn enter() void {
        timer.reset();
    }

    fn update(delta: f32) void {
        if (timer.isFinishedAfterUpdate(delta)) {
            tip = &.{};
            changePhase(next);
        }
    }

    fn draw() void {
        if (tip.len == 0) return;
        camera.drawText(tip, .init(290, 210));
    }
};

const EnemyAttackPhase = struct {
    fn enter() void {
        audio.playSound(attackSounds[enemySounds[enemy.picture]]);
        bombAnimation.reset();
    }

    fn update(delta: f32) void {
        if (bombAnimation.isFinishedAfterUpdate(delta)) changePhase(.playerHurt);
    }

    fn draw() void {
        camera.draw(bombAnimation.currentTexture(), .init(120, 220));
    }
};

const PlayerHurtPhase = struct {
    var damage: u16 = 0;
    var timer: window.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter() void {
        audio.playSound(hurtSounds[0]);

        damage = computeDamage(enemy.attack, player.defend);
        player.health -|= damage;

        timer.reset();
    }

    fn update(delta: f32) void {
        if (timer.isFinishedAfterUpdate(delta)) {
            changePhase(if (player.health == 0) .playerDeath else .menu);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw() void {
        const pos = math.Vector2.init(130, 220).addX(offset);
        camera.draw(player.battleTexture(), pos);

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        camera.drawText(text, .init(130, y));
    }
};

const PlayerDeathPhase = struct {
    fn enter() void {
        audio.playSound(deadSounds[0]);
    }

    fn update(_: f32) void {
        if (window.isAnyRelease()) scene.changeScene(.title);
    }

    fn draw() void {
        camera.drawText("你死了！", .init(285, 200));
    }
};

const EnemyDeathPhase = struct {
    var step: u8 = 0;

    fn enter() void {
        audio.playSound(deadSounds[enemySounds[enemy.picture]]);
        step = 0;
        npc.death(enemyIndex);
        if (enemy.progress != 0xFF) player.progress = enemy.progress + 1;
    }

    fn update(_: f32) void {
        if (step == 0 and window.isAnyRelease()) {
            step += 1;
            player.exp += enemy.level * 20;
            player.money += enemy.money;
            for (enemy.goods) |index| _ = player.addItem(index);
            return;
        }

        if (step == 1 and window.isAnyRelease()) {
            if (player.isLevelUp()) {
                step += 1;
                return player.levelUp();
            }
        }

        if (window.isAnyRelease()) scene.changeScene(.world);
    }

    fn draw() void {
        camera.drawText("胜利了！", .init(285, 175));
        if (step < 1) return;

        var buffer: [100]u8 = undefined;
        var text = zhu.format(&buffer, "获得：经验=[{}] 金钱=[{}]", .{
            enemy.level * 20,
            enemy.money,
        });
        camera.drawText(text, .init(220, 210));

        if (enemy.goods.len != 0) {
            camera.drawText("缴获物品：", .init(220, 240));

            for (enemy.goods) |index| {
                const name = item.zon[index].name;
                camera.drawColorText(name, .init(310, 240), .yellow);
            }

            std.debug.assert(enemy.goods.len == 1);
        }
        if (step == 2) {
            text = zhu.format(&buffer, "等级升为({})^_^", .{player.level});
            camera.drawColorText(text, .init(260, 270), .yellow);
        }
    }
};

const StatusPhase = struct {
    fn update(_: f32) void {
        if (window.isAnyRelease()) changePhase(.menu);
    }

    fn draw() void {
        camera.flushText();
        player.drawStatus();
    }
};

const ItemPhase = struct {
    fn update(_: f32) void {
        const used = player.openItem();
        if (used) changePhase(.enemyAttack);

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q })) changePhase(.menu);
    }

    fn draw() void {
        camera.flushText();
        player.drawOpenItem();
    }
};
