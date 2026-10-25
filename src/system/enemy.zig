const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Collider = component.Collider;
const Enemy = component.actor.Enemy;
const Facing = component.actor.Facing;
const Interact = component.Interact;
const Player = component.actor.Player;
const Position = component.Position;
const Request = component.event.Request;
const Talk = component.dialog.Talk;

pub fn update(world: *ecs.World, delta: f32) void {
    const player = world.getIdentityEntity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const area = collider.move(position);

    var query = world.query(.{ Position, Enemy });
    while (query.next()) |entity| {
        const pos = query.get(entity, Position);
        const enemy = query.getPtr(entity, Enemy);
        if (enemy.wait > 0) {
            enemy.wait -= delta;
            continue;
        }
        if (!area.intersect(enemy.value.move(pos))) continue;

        const facing = world.get(player, Facing).?;
        world.add(entity, component.actor.oppositeFacing(facing));
        // 有对话的敌人先进入对话，否则直接进入战斗。
        if (world.has(entity, Talk)) {
            world.addIdentity(entity, Interact);
        } else {
            world.removeIdentity(Interact);
            world.addIdentity(entity, Enemy);
            world.addEvent(Request.battle);
        }
        return;
    }
}

test "玩家进入敌人区域后选择战斗对象" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(0, 32),
        Enemy{ .value = .init(.xy(-24, -40), .xy(48, 48)) },
        Facing.down,
    });

    update(&world, 1);

    try std.testing.expect(world.isIdentity(entity, Enemy));
    try std.testing.expectEqual(Request.battle, world.getEvent(Request)[0]);
    try std.testing.expectEqual(Facing.up, world.get(entity, Facing).?);
}

test "玩家接触有对话的敌人后选择交互对象" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    const lines: Talk = &.{
        .{ .actor = null, .content = "战斗前对话" },
    };
    world.addAll(entity, .{
        Position.xy(0, 32),
        Enemy{ .value = .init(.xy(-24, -40), .xy(48, 48)) },
        Facing.down,
        lines,
    });

    update(&world, 1);

    try std.testing.expect(world.isIdentity(entity, Interact));
    try std.testing.expect(!world.hasIdentity(Enemy));
    try std.testing.expectEqual(0, world.getEvent(Request).len);
}

test "玩家在敌人区域外时不选择战斗对象" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(100, 100),
        Enemy{ .value = .init(.xy(-24, -40), .xy(48, 48)) },
        Facing.down,
    });

    update(&world, 1);

    try std.testing.expect(!world.hasIdentity(Enemy));
}

test "逃跑冷却期间不再触发战斗" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(0, 32),
        Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
            .wait = 0.5,
        },
        Facing.down,
    });

    update(&world, 0.25);

    try std.testing.expect(!world.hasIdentity(Enemy));
    try std.testing.expectEqual(
        @as(f32, 0.25),
        world.get(entity, Enemy).?.wait,
    );
}
