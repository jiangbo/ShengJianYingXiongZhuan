const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const audio = zhu.audio;
const math = zhu.math;

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const shared = @import("shared.zig");

const Story = component.event.Story;

pub const Attack = struct {
    // 开始敌方攻击动画。
    pub fn enter(_: *ecs.World) void {
        audio.playSound(
            shared.attackSounds[
                shared.enemySounds[shared.enemy.picture]
            ],
        );
        shared.bombAnimation.reset();
    }

    // 攻击动画结束后进入玩家受伤阶段。
    pub fn update(_: *ecs.World, delta: f32) ?shared.Phase {
        if (shared.bombAnimation.update(delta) == .end) {
            return .playerHurt;
        }
        return null;
    }

    // 在玩家位置绘制攻击动画。
    pub fn draw(_: *ecs.World) void {
        const image = shared.bombAnimation.subImage();
        zhu.batch.drawImage(image, .xy(120, 220), .{});
    }
};

pub const Hurt = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    // 计算敌方受到的伤害并开始受伤动画。
    pub fn enter(world: *ecs.World) void {
        audio.playSound(
            shared.hurtSounds[
                shared.enemySounds[shared.enemy.picture]
            ],
        );

        const stats = world.getResourcePtr(storage.Stats).?;
        damage = shared.computeDamage(stats.attack, shared.enemy.defend);
        shared.enemy.health -|= damage;
        timer.restart();
        offset = 0;
    }

    // 受伤动画结束后判断敌方是否死亡。
    pub fn update(_: *ecs.World, delta: f32) ?shared.Phase {
        if (timer.updateFinished(delta)) {
            if (shared.enemy.health == 0) return .enemyDeath;

            return shared.wait(.enemyAttack, &.{});
        }

        const period: u8 = @intFromFloat(
            @trunc(timer.elapsed / 0.08),
        );
        offset = if (period % 2 == 0) -5 else 5;
        return null;
    }

    // 绘制敌方抖动和伤害数字。
    pub fn draw(_: *ecs.World) void {
        const position = math.Vector2.xy(465, 237).addX(offset);
        const image = zon.Actor.image(shared.enemyKey, .left);
        zhu.batch.drawImage(image, position, .{});

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(465, y), .{});
    }
};

pub const Death = struct {
    var step: u8 = 0;
    // 本次战斗掉落物是否已经放入背包。
    var itemAdded: bool = false;

    // 播放敌方死亡声音并发送剧情进度事件。
    pub fn enter(world: *ecs.World) void {
        audio.playSound(
            shared.deadSounds[
                shared.enemySounds[shared.enemy.picture]
            ],
        );
        step = 0;
        itemAdded = false;
        if (shared.enemy.progress != 0xFF) {
            world.addEvent(Story{
                .progress = shared.enemy.progress,
            });
        }
    }

    // 依次结算奖励、升级和战斗结果。
    pub fn update(world: *ecs.World, _: f32) ?shared.Phase {
        const stats = world.getResourcePtr(storage.Stats).?;
        const inventory = world.getResourcePtr(storage.Inventory).?;
        // 确认键或鼠标左键松开后推进结算。
        const confirmed = zon.input.released(.confirm) or
            zhu.key.released(.MOUSE_LEFT);
        if (step == 0 and confirmed) {
            step += 1;
            stats.exp += shared.enemy.level * 20;
            inventory.money += shared.enemy.money;
            for (shared.enemy.goods) |itemKey| {
                itemAdded = inventory.add(itemKey);
            }
            return null;
        }

        if (step == 1 and confirmed) {
            if (stats.levelUp()) {
                step += 1;
                return null;
            }
        }

        if (confirmed) {
            return .win;
        }
        return null;
    }

    // 绘制胜利、奖励和升级提示。
    pub fn draw(world: *ecs.World) void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();

        zhu.text.draw("胜利了！", .xy(285, 175), .{});
        if (step < 1) return;

        var buffer: [100]u8 = undefined;
        var text = zhu.format(
            &buffer,
            "获得：经验=[{}] 金钱=[{}]",
            .{ shared.enemy.level * 20, shared.enemy.money },
        );
        zhu.text.draw(text, .xy(220, 210), .{});

        if (shared.enemy.goods.len != 0) {
            std.debug.assert(shared.enemy.goods.len == 1);
            const name = zon.Item.get(shared.enemy.goods[0]).name;
            text = if (itemAdded)
                zhu.format(&buffer, "缴获物品：{s}", .{name})
            else
                zhu.format(&buffer, "背包已满，未获得：{s}", .{name});
            zhu.text.draw(text, .xy(220, 240), .{ .color = .yellow });
        }
        if (step == 2) {
            const level = world.getResourcePtr(storage.Stats).?.level;
            text = zhu.format(
                &buffer,
                "等级升为({})^_^",
                .{level},
            );
            zhu.text.draw(
                text,
                .xy(260, 270),
                .{ .color = .yellow },
            );
        }
    }
};
