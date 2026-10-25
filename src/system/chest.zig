const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");

const Chest = component.Chest;
const ChestImages = component.ChestImages;
const Dialog = component.dialog.Dialog;
const Interact = component.Interact;
const Sprite = component.Sprite;
const Tip = component.event.Tip;

pub fn update(world: *ecs.World) void {
    const entity = world.getIdentityEntity(Interact) orelse return;
    const chest = world.get(entity, Chest) orelse return;
    world.removeIdentity(Interact);
    const config = zon.Chest.get(chest.id);
    const inventory = world.getResourcePtr(storage.Inventory).?;

    if (config.item) |key| {
        if (!inventory.add(key)) {
            world.addEvent(Tip{ .text = "你已经带满了！" });
            return;
        }
        world.addResource(Dialog{
            .lines = zon.dialogues[1].lines,
            .value = .{ .text = zon.Item.get(key).name },
        });
    } else {
        const gold = zhu.random.int(u8, 10, 100);
        inventory.money += gold;
        world.addResource(Dialog{
            .lines = zon.dialogues[0].lines,
            .value = .{ .number = gold },
        });
    }

    const opened = world.getResourcePtr(storage.OpenedChests).?;
    opened.set(chest.id);
    const images = world.get(entity, ChestImages).?;
    world.getPtr(entity, Sprite).?.image = images.opened;
    world.remove(entity, Interact);
}

test "背包已满时不打开宝箱" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    var inventory = storage.Inventory{};
    for (&inventory.items) |*item| item.* = .zhiXueCao;
    world.addResource(storage.OpenedChests.empty);
    world.addResource(inventory);

    const entity = world.createEntity();
    world.addAll(entity, .{
        Chest{ .id = 6 },
        Interact{},
    });
    world.addIdentity(entity, Interact);

    update(&world);

    const opened = world.getResourcePtr(storage.OpenedChests).?;
    try std.testing.expect(!opened.isSet(6));
    try std.testing.expect(world.has(entity, Interact));
    try std.testing.expect(!world.hasIdentity(Interact));
    try std.testing.expectEqual(1, world.getEvent(Tip).len);
    try std.testing.expect(world.getResourcePtr(Dialog) == null);
}
