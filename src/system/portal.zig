const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");

const Collider = component.Collider;
const Dialog = component.dialog.Dialog;
const Player = component.actor.Player;
const Portal = component.Portal;
const Position = component.Position;
const Request = component.event.Request;

pub fn update(world: *ecs.World) void {
    const player = world.getIdentityEntity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const center = collider.move(position).center();

    if (world.getIdentity(Portal, null)) |portal| {
        if (portal.area.contains(center)) return;
        world.removeIdentity(Portal);
    }

    const portal = enterPortal(world, center) orelse return;
    const data = zon.Portal.get(portal.key);
    const gate = data.gate orelse return requestMap(world);

    const progress = world.getResourcePtr(storage.Progress).?.value;
    if (progress > gate.progress) return requestMap(world);

    var dialogueId = gate.blockedDialogue;
    if (progress == gate.progress) {
        if (gate.reachedDialogue) |id| dialogueId = id;
    }

    world.addResource(Dialog{
        .lines = zon.dialogues[dialogueId].lines,
    });
}

// 查找玩家所在的传送区域，并记录为当前传送门。
fn enterPortal(world: *ecs.World, center: Position) ?Portal {
    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (!portal.area.contains(center)) continue;

        world.addIdentity(entity, Portal);
        return portal;
    }
    return null;
}

fn requestMap(world: *ecs.World) void {
    world.addEvent(Request.map);
}

test "选择玩家当前所在的传送区域" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addResource(storage.Progress{});
    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.zero, .square(16)),
    });

    const portal = world.createEntity();
    world.add(portal, Portal{
        .key = .homeToCity,
        .area = .init(.zero, .square(32)),
    });

    update(&world);
    try std.testing.expect(world.isIdentity(portal, Portal));

    world.add(player, Position.xy(32, 0));
    update(&world);
    try std.testing.expect(!world.hasIdentity(Portal));
}

test "未击败巫批时宫殿入口显示受阻对话" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addResource(storage.Progress{ .value = 5 });
    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.zero, .square(16)),
    });

    const portal = world.createEntity();
    world.add(portal, Portal{
        .key = .forestToPalace,
        .area = .init(.zero, .square(32)),
    });

    update(&world);

    const dialog = world.getResourcePtr(Dialog).?;
    try std.testing.expectEqual(
        zon.dialogues[37].lines.ptr,
        dialog.lines.ptr,
    );
    try std.testing.expect(world.isIdentity(portal, Portal));
    try std.testing.expectEqual(0, world.getEvent(Request).len);

    world.removeResource(Dialog);
    update(&world);
    try std.testing.expect(world.getResourcePtr(Dialog) == null);
}

test "到达城市出口条件时触发大魔王剧情" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addResource(storage.Progress{ .value = 4 });
    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.zero, .square(16)),
    });

    const portal = world.createEntity();
    world.add(portal, Portal{
        .key = .cityToForest,
        .area = .init(.zero, .square(32)),
    });

    update(&world);

    const dialog = world.getResourcePtr(Dialog).?;
    try std.testing.expectEqual(
        zon.dialogues[32].lines.ptr,
        dialog.lines.ptr,
    );
    try std.testing.expectEqual(0, world.getEvent(component.event.Story).len);
    try std.testing.expect(world.isIdentity(portal, Portal));
    try std.testing.expectEqual(0, world.getEvent(Request).len);
}
