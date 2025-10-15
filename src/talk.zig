const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const player = @import("player.zig");
const npc = @import("npc.zig");

const Talk = struct {
    actor: u8 = 0,
    content: []const u8 = &.{},
    next: u16 = 1, // 0：表示结束，1：表示下一条
    event: u8 = 0,
};
const zon: []const Talk = @import("zon/talk.zon");
var texture: gfx.Texture = undefined;

pub var active: u16 = 0;
pub var actor: u16 = 0;
var textIndex: usize = 0;
var text: [50]u8 = undefined;
var plainText: bool = true;

var buffer: [256]u8 = undefined;
var bufferIndex: usize = 0;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/talkbar.png", .init(640, 96));
}

pub fn activeNumber(talkId: u16, number: anytype) void {
    const content = zhu.format(text[20..], "{d}", .{number});
    activeText(talkId, content);
}

pub fn activeText(talkId: u16, content: []const u8) void {
    active = talkId;
    @memcpy(text[0..content.len], content);
    textIndex = content.len;
    bufferIndex = 0;
    plainText = false;
}

pub fn activeNext() void {
    active += 1;
    actor = zon[active].actor;
}

pub fn recentNpc() u16 {
    var npcIndex = active;
    while (zon[npcIndex].actor == 0) {
        npcIndex -= 1;
    }
    return zon[npcIndex].actor;
}

pub fn update() ?u8 {
    if (!window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) return null;

    if (zon[active].event != 0 or zon[active].next == 0) {
        plainText = true;
        return zon[active].event;
    }
    active += zon[active].next;
    actor = zon[active].actor;
    return null;
}

pub fn draw() void {
    camera.draw(texture, .init(0, 384));

    const talk = zon[active];
    if (talk.actor == 0)
        player.drawTalk()
    else if (talk.actor < 200)
        npc.drawTalk(talk.actor);

    if (plainText) return drawText(talk.content);

    if (bufferIndex != 0) {
        drawText(buffer[0..bufferIndex]);
    } else {
        drawText(formatStr(talk.content));
    }
}

pub fn drawText(content: []const u8) void {
    camera.drawTextOptions(content, .{
        .color = .black,
        .position = .init(123, 400),
        .width = 593,
    });
    camera.drawTextOptions(content, .{
        .color = .white,
        .position = .init(120, 397),
        .width = 590,
    });
}

fn formatStr(content: []const u8) []const u8 {
    const str = text[0..textIndex];
    const times = std.mem.replace(u8, content, "{}", str, &buffer);
    std.debug.assert(times == 1);

    bufferIndex = content.len - 2 + str.len;
    return buffer[0..bufferIndex];
}
