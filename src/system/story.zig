const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");

const Key = component.actor.Key;
const Speed = component.Speed;
const Story = component.event.Story;
const Talk = component.dialog.Talk;
const Wander = component.actor.Wander;

pub fn update(world: *ecs.World) void {
    for (world.getEvent(Story)) |story| {
        const progress = world.getResourcePtr(storage.Progress).?;
        const next = story.progress + 1;
        std.debug.assert(progress.value <= next);
        progress.value = next;

        switch (next) {
            // 进度 4：柔儿获救后开始移动。
            4 => rouErRescued(world),
            // 进度 5：大魔王出现。
            5 => demonAppeared(world, next),
            else => {},
        }
    }
    world.clearEvent(Story);
}

// 为获救后的柔儿启用漫游行为。
fn rouErRescued(world: *ecs.World) void {
    var query = world.query(.{Key});
    while (query.next()) |entity| {
        if (query.get(entity, Key) != .rouEr) continue;
        world.add(entity, Wander{ .value = .init(0) });
        return;
    }
    unreachable;
}

// 处理大魔王出现后的城市人物变化。
fn demonAppeared(world: *ecs.World, progress: u8) void {
    var query = world.query(.{ Key, Talk, Speed });
    while (query.next()) |entity| {
        const actorKey = query.get(entity, Key);
        const talk = query.getPtr(entity, Talk);
        const speed = query.getPtr(entity, Speed);
        const actor = zon.Actor.get(actorKey);
        talk.* = actor.talk(progress);
        speed.value = actor.moveSpeed(progress);
    }
}

test "大魔王出现后更新人物的对话和速度" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addResource(storage.Progress{ .value = 4 });
    const entity = world.createEntity();
    const oldTalk: Talk = &.{
        .{ .actor = null, .content = "旧对话" },
    };
    world.addAll(entity, .{
        Key.daYou,
        oldTalk,
        Speed{ .value = 14 },
    });
    world.addEvent(Story{ .progress = 4 });

    update(&world);

    const progress = world.getResourcePtr(storage.Progress).?;
    const talk = world.get(entity, Talk).?;
    const speed = world.get(entity, Speed).?;
    try std.testing.expectEqual(5, progress.value);
    try std.testing.expect(talk.ptr != oldTalk.ptr);
    try std.testing.expect(speed.value != 14);
}
