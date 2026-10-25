const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const dialog = component.dialog;
const Dialog = dialog.Dialog;
const Facing = component.actor.Facing;
const Interact = component.Interact;
const Player = component.actor.Player;
const Talk = dialog.Talk;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World) void {
    const target = world.getIdentityEntity(Interact) orelse return;
    const lines = world.get(target, Talk) orelse return;
    world.removeIdentity(Interact);

    // 已有对话优先，丢弃本次人物交互。
    if (world.getResourcePtr(Dialog) != null) return;

    const facing = world.getIdentity(Player, Facing).?;
    world.add(target, component.actor.oppositeFacing(facing));
    world.remove(target, WantMove);

    world.addResource(Dialog{ .lines = lines });
}

fn addTestPlayer(world: *ecs.World) ecs.Entity {
    const playerEntity = world.createIdentity(Player);
    world.add(playerEntity, Facing.down);
    return playerEntity;
}

test "交互对话人物后添加对话状态" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world);
    const target = world.createEntity();
    const lines: Talk = &.{
        .{ .actor = null, .content = "测试对话" },
    };
    world.addAll(target, .{
        Facing.down,
        Interact{},
        lines,
        WantMove{ .value = .xy(0, 1) },
    });
    world.addIdentity(target, Interact);

    update(&world);
    try std.testing.expect(world.getResourcePtr(Dialog) != null);
    const current = world.getResourcePtr(Dialog).?;
    try std.testing.expectEqual(lines.ptr, current.lines.ptr);
    try std.testing.expect(!world.has(target, Dialog));
    try std.testing.expectEqual(Facing.up, world.get(target, Facing).?);
    try std.testing.expect(!world.has(target, WantMove));
    try std.testing.expect(!world.hasIdentity(Interact));
}

test "没有对话能力的交互对象不会开始对话" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world);
    const target = world.createEntity();
    world.add(target, Interact{});
    world.addIdentity(target, Interact);

    update(&world);
    try std.testing.expect(world.getResourcePtr(Dialog) == null);
}
