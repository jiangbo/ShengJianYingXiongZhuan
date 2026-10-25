const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../zon.zig").input;

const Collider = component.Collider;
const Facing = component.actor.Facing;
const Interact = component.Interact;
const Player = component.actor.Player;
const Position = component.Position;

pub fn update(world: *ecs.World) void {
    if (!input.released(.confirm)) return;

    const target = nearestEntity(world) orelse return;
    world.addIdentity(target, Interact);
}

// 获取玩家交互区域内距离中心最近的实体。
fn nearestEntity(world: *ecs.World) ?ecs.Entity {
    const area = playerArea(world);
    var nearest: ?ecs.Entity = null;
    var distance2 = std.math.inf(f32);
    var query = world.query(.{ Position, Collider, Interact });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const collider = query.get(entity, Collider);
        const targetArea = collider.move(position);
        if (!area.intersect(targetArea)) continue;

        const nextDistance2 = area.center().sub(
            targetArea.center(),
        ).length2();
        if (nextDistance2 >= distance2) continue;
        nearest = entity;
        distance2 = nextDistance2;
    }
    return nearest;
}

// 从玩家碰撞区域的中心向当前朝向生成交互区域。
fn playerArea(world: *ecs.World) zhu.Rect {
    const player = world.getIdentityEntity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const facing = world.get(player, Facing).?;

    const center = collider.move(position).center();
    const size = zhu.Vector2.xy(32, 32);
    const min = switch (facing) {
        .down => center.addXY(-size.x * 0.5, 0),
        .left => center.addXY(-size.x, -size.y * 0.5),
        .up => center.addXY(-size.x * 0.5, -size.y),
        .right => center.addXY(0, -size.y * 0.5),
    };
    return .init(min, size);
}

test "交互系统选择玩家正前方最近的实体" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const near = world.createEntity();
    world.addAll(near, .{
        Position.xy(0, 32),
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Interact{},
    });

    const far = world.createEntity();
    world.addAll(far, .{
        Position.xy(0, 48),
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Interact{},
    });

    zhu.key.set(.F, true);
    zhu.input.update();
    zhu.key.set(.F, false);
    update(&world);

    try std.testing.expect(world.isIdentity(near, Interact));
}
