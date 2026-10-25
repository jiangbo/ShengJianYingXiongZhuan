const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");

const Dialog = component.dialog.Dialog;
const Enemy = component.actor.Enemy;
const Key = component.actor.Key;
const Request = component.event.Request;
const Story = component.event.Story;

var texture: zhu.Image = undefined;
// 动态文本格式化后存放在此缓冲区。
var buffer: [256]u8 = undefined;

pub fn init() void {
    texture = zhu.getImage("talkbar.png").?;
}

pub fn update(world: *ecs.World) ?zon.dialog.Event {
    const dialog = world.getResourcePtr(Dialog) orelse return null;
    if (dialog.text == null) {
        prepareText(dialog);
        return null;
    }
    // 松开确认键或鼠标左键后推进对话。
    if (!zon.input.released(.confirm) and
        !zhu.key.released(.MOUSE_LEFT)) return null;

    const line = dialog.lines[dialog.line];
    if (line.event) |event| {
        switch (event) {
            .battle => |key| startBattle(world, dialog, key),
            .unlock => |progress| {
                world.removeResource(Dialog);
                world.addEvent(Story{ .progress = progress });
                world.addEvent(Request.map);
            },
            else => world.removeResource(Dialog),
        }
        return event;
    }

    if (dialog.line + 1 == dialog.lines.len) {
        world.removeResource(Dialog);
        return .finish;
    }

    dialog.line += 1;
    prepareText(dialog);
    return null;
}

// 选择对话指定的敌人，并将对话推进到战斗后的内容。
fn startBattle(world: *ecs.World, dialog: *Dialog, key: Key) void {
    var query = world.query(.{Key});
    while (query.next()) |entity| {
        if (query.get(entity, Key) != key) continue;
        world.addIdentity(entity, Enemy);

        if (dialog.line + 1 == dialog.lines.len) {
            world.removeResource(Dialog);
        } else {
            dialog.line += 1;
            prepareText(dialog);
        }
        return;
    }
    unreachable;
}

pub fn draw(world: *ecs.World) void {
    const dialog = world.getResourcePtr(Dialog) orelse return;
    const text = dialog.text orelse return;
    const line = dialog.lines[dialog.line];

    zhu.batch.drawImage(texture, .xy(0, 384), .{});
    if (line.actor) |key| drawActor(key);

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    drawText(text);
}

fn prepareText(dialog: *Dialog) void {
    const line = dialog.lines[dialog.line];
    const value = dialog.value orelse {
        dialog.text = line.content;
        return;
    };

    var buf: [20]u8 = undefined;
    const text = switch (value) {
        .number => |number| zhu.format(&buf, "{d}", .{number}),
        .text => |v| v,
    };
    const times = std.mem.replace(u8, line.content, "{}", text, &buffer);
    std.debug.assert(times == 1);
    const length = line.content.len - 2 + text.len;
    dialog.text = buffer[0..length];
}

fn drawActor(key: zon.Actor.Key) void {
    const actor = zon.Actor.get(key);
    var pos: zhu.Vector2 = .xy(40, 400);
    if (key == .player) pos = .xy(35, 396);
    const image = zon.Actor.image(key, .down);
    zhu.batch.drawImage(image, pos, .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(actor.name, .xy(25, 445), .{ .color = .yellow });
}

fn drawText(content: []const u8) void {
    zhu.text.draw(content, .xy(123, 400), .{ .color = .black, .max = 470 });
    zhu.text.draw(content, .xy(120, 397), .{ .color = .white, .max = 470 });
}
