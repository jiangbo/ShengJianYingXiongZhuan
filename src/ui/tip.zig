const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Tip = component.event.Tip;

// 当前显示的临时提示。
var text: []const u8 = &.{};
var timer: zhu.Timer = .initFinished(2);

pub fn reset() void {
    text = &.{};
    timer.stop();
}

pub fn update(world: *ecs.World, delta: f32) void {
    for (world.getEvent(Tip)) |event| {
        text = event.text;
        timer.restart();
    }
    world.clearEvent(Tip);

    if (text.len != 0 and timer.updateFinished(delta)) text = &.{};
}

pub fn draw() void {
    if (text.len == 0) return;

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(text, .xy(322, 62), .{
        .anchor = .xy(0.5, 0),
        .color = .black,
    });
    zhu.text.draw(text, .xy(320, 60), .{
        .anchor = .xy(0.5, 0),
        .color = .yellow,
    });
}
