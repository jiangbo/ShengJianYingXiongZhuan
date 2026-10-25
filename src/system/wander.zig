const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Facing = component.actor.Facing;
const Wander = component.actor.Wander;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{Wander});
    while (query.next()) |entity| {
        const wander = query.getPtr(entity, Wander);
        if (wander.value.updateRunning(delta)) continue;

        wander.value = .init(zhu.random.float(3, 5));
        const facing = zhu.random.enumValue(Facing);
        world.addAll(entity, .{
            facing,
            WantMove{ .value = switch (facing) {
                .down => .xy(0, 1),
                .left => .xy(-1, 0),
                .up => .xy(0, -1),
                .right => .xy(1, 0),
            } },
        });
    }
}

test "漫游转向时更新移动意图" {
    zhu.random.init(0);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Facing.left);
    world.add(entity, Wander{ .value = .init(0) });
    world.add(entity, WantMove{ .value = .xy(-1, 0) });

    update(&world, 0);

    const facing = world.get(entity, Facing).?;
    const wantMove = world.get(entity, WantMove).?;
    const direction: zhu.Vector2 = switch (facing) {
        .down => .xy(0, 1),
        .left => .xy(-1, 0),
        .up => .xy(0, -1),
        .right => .xy(1, 0),
    };
    try std.testing.expect(wantMove.value.approxEqual(direction));
}
