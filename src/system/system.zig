const ecs = @import("ecs");

pub const chest = @import("chest.zig");
pub const control = @import("control.zig");
pub const dialog = @import("dialog.zig");
pub const enemy = @import("enemy.zig");
pub const interact = @import("interact.zig");
pub const movement = @import("movement.zig");
pub const portal = @import("portal.zig");
pub const render = @import("render.zig");
pub const story = @import("story.zig");
pub const wander = @import("wander.zig");

pub fn update(world: *ecs.World, delta: f32) void {
    story.update(world);
    wander.update(world, delta);
    control.update(world);
    movement.update(world, delta);
    portal.update(world);
    interact.update(world);
    enemy.update(world, delta);
    chest.update(world);
    dialog.update(world);
    render.update(world, delta);
}
