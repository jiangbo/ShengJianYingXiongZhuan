const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../zon.zig").input;

const Facing = component.actor.Facing;
const Player = component.actor.Player;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World) void {
    const entity = world.getIdentityEntity(Player).?;
    const facing = world.getPtr(entity, Facing).?;
    const direction = readDirection();

    if (direction.length2() == 0) {
        return world.remove(entity, WantMove);
    }

    world.add(entity, WantMove{ .value = direction });
    if (chooseFacing(direction)) |value| facing.* = value;
}

fn readDirection() zhu.Vector2 {
    var direction: zhu.Vector2 = .zero;

    if (input.held(.up)) direction.y -= 1;
    if (input.held(.down)) direction.y += 1;
    if (input.held(.left)) direction.x -= 1;
    if (input.held(.right)) direction.x += 1;

    if (direction.length2() == 0) return .zero;
    return direction.normalize();
}

fn chooseFacing(direction: zhu.Vector2) ?Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    } else if (@abs(direction.y) > @abs(direction.x)) {
        return if (direction.y < 0) .up else .down;
    }

    // 两个轴相等时，新按下的方向决定角色朝向。
    if (input.pressed(.right)) return .right;
    if (input.pressed(.left)) return .left;
    if (input.pressed(.down)) return .down;
    if (input.pressed(.up)) return .up;
    return null;
}

test "斜向移动使用最后按下的方向" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createIdentity(Player);
    world.add(entity, Facing.down);

    zhu.key.set(.W, true);
    update(&world);
    var facing = world.get(entity, Facing).?;
    var wantMove = world.get(entity, WantMove).?;
    try std.testing.expect(wantMove.value.approxEqual(.xy(0, -1)));
    try std.testing.expectEqual(Facing.up, facing);

    zhu.input.update();
    zhu.key.set(.D, true);
    update(&world);
    facing = world.get(entity, Facing).?;
    wantMove = world.get(entity, WantMove).?;
    try std.testing.expectApproxEqAbs(1, wantMove.value.length(), 0.001);
    try std.testing.expectEqual(Facing.right, facing);

    zhu.input.update();
    zhu.key.set(.D, false);
    update(&world);
    facing = world.get(entity, Facing).?;
    wantMove = world.get(entity, WantMove).?;
    try std.testing.expect(wantMove.value.approxEqual(.xy(0, -1)));
    try std.testing.expectEqual(Facing.up, facing);

    zhu.input.update();
    zhu.key.set(.W, false);
    update(&world);
    try std.testing.expect(!world.has(entity, WantMove));
}
