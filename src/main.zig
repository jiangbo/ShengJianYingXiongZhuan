const std = @import("std");

const window = @import("zhu").window;
const audio = @import("zhu").audio;
const scene = @import("scene.zig");

var soundBuffer: [20]audio.Sound = undefined;

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

pub fn init() void {
    audio.init(8000, &soundBuffer);

    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
    audio.deinit();
}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (@import("builtin").mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (@import("builtin").mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    if (@import("builtin").os.tag == .windows) {
        _ = ImmDisableIME(-1);
    }

    window.run(allocator, .{
        .title = "英雄救美",
        .logicSize = .{ .x = 640, .y = 480 },
    });
}
