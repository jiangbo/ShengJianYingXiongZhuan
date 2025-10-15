const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const gpu = @import("gpu.zig");

pub const Event = sk.app.Event;

pub const Timer = struct {
    duration: f32,
    elapsed: f32 = 0,

    pub fn init(duration: f32) Timer {
        return Timer{ .duration = duration };
    }

    pub fn update(self: *Timer, delta: f32) void {
        if (self.elapsed < self.duration) self.elapsed += delta;
    }

    pub fn isRunningAfterUpdate(self: *Timer, delta: f32) bool {
        self.update(delta);
        return self.isRunning();
    }

    pub fn isFinishedAfterUpdate(self: *Timer, delta: f32) bool {
        return !self.isRunningAfterUpdate(delta);
    }

    pub fn isRunning(self: *const Timer) bool {
        return self.elapsed < self.duration;
    }

    pub fn progress(self: *const Timer) f32 {
        return self.elapsed / self.duration;
    }

    pub fn restart(self: *Timer) void {
        self.elapsed = self.elapsed - self.duration;
    }

    pub fn stop(self: *Timer) void {
        self.elapsed = self.duration;
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};

const CountingAllocator = struct {
    child: std.mem.Allocator,
    used: u64 = 0,
    count: u64 = 0,

    pub fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child };
    }

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    const A = std.mem.Alignment;
    fn alloc(c: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        return p;
    }

    fn resize(c: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used += len;
            self.used -= b.len;
        }
        return stable;
    }

    fn remap(c: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        if (n != m.ptr) {
            self.used -= m.len;
            self.used += len;
        }
        return n;
    }

    fn free(c: *anyopaque, buf: []u8, a: A, r: usize) void {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        self.used -= buf.len;
        return self.child.rawFree(buf, a, r);
    }
};

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub fn toggleFullScreen() void {
    sk.app.toggleFullscreen();
}

pub const WindowInfo = struct {
    title: [:0]const u8,
    logicSize: math.Vector,
    scale: f32 = 1,
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var logicSize: math.Vector = .zero;
pub var clientSize: math.Vector = .zero;
pub var ratio: math.Vector = .init(1, 1);
pub var displayArea: math.Rect = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var countingAllocator: CountingAllocator = undefined;
var timer: std.time.Timer = undefined;

const root = @import("root");
pub fn run(alloc: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    logicSize = info.logicSize;
    displayArea = .init(.zero, logicSize);
    countingAllocator = CountingAllocator.init(alloc);
    allocator = countingAllocator.allocator();

    const size = logicSize.scale(info.scale);
    sk.app.run(.{
        .window_title = info.title,
        .width = @as(i32, @intFromFloat(size.x)),
        .height = @as(i32, @intFromFloat(size.y)),
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
        .high_dpi = true,
    });
}

export fn windowInit() void {
    clientSize = .init(sk.app.widthf(), sk.app.heightf());
    ratio = clientSize.div(logicSize);
    assets.init(allocator);
    gpu.init();
    math.setRandomSeed(timer.lap());
    call(root, "init", .{});
}

pub var mouseMoved: bool = false;
pub var mousePosition: math.Vector = .zero;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        if (ev.type == .MOUSE_MOVE) {
            mouseMoved = true;
            const pos = input.mousePosition.sub(displayArea.min);
            mousePosition = pos.mul(logicSize).div(displayArea.size);
        } else if (ev.type == .RESIZED) {
            clientSize = .init(sk.app.widthf(), sk.app.heightf());
            ratio = clientSize.div(logicSize);
        }
        call(root, "event", .{ev});
    }
}

pub fn keepAspectRatio() void {
    const minSize = logicSize.scale(@min(ratio.x, ratio.y));
    const pos = clientSize.sub(minSize).scale(0.5);
    displayArea = .init(pos, minSize);
    sk.gfx.applyViewportf(pos.x, pos.y, minSize.x, minSize.y, true);
}

var frameRateTimer: Timer = .init(1);
var frameRateCount: u32 = 0;
var usedDelta: u64 = 0;
pub var frameRate: u32 = 0;
pub var frameDeltaPerSecond: f32 = 0;
pub var usedDeltaPerSecond: f32 = 0;

export fn windowFrame() void {
    const deltaNano: f32 = @floatFromInt(timer.lap());
    const delta = deltaNano / std.time.ns_per_s;
    defer usedDelta = timer.read();

    if (frameRateTimer.isFinishedAfterUpdate(delta)) {
        frameRateTimer.restart();
        frameRate = frameRateCount;
        frameRateCount = 1;
        frameDeltaPerSecond = delta * 1000;
        const deltaUsed: f32 = @floatFromInt(usedDelta);
        usedDeltaPerSecond = deltaUsed / std.time.ns_per_ms;
    } else frameRateCount += 1;

    sk.fetch.dowork();
    gpu.begin(.{ .a = 1 });
    // gpu.begin(.{ .r = 1, .b = 1, .a = 1 });
    call(root, "frame", .{delta});
    gpu.end();
    input.lastKeyState = input.keyState;
    input.lastMouseState = input.mouseState;
    input.anyRelease = false;
    mouseMoved = false;
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn frameCount() u64 {
    return sk.app.frameCount();
}

pub fn statFileTime(path: [:0]const u8) i64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();

    const stat = file.stat() catch return 0;
    return @intCast(stat.mtime);
}

pub fn readAll(path: [:0]const u8, content: []u8) ![]u8 {
    if (@import("builtin").target.os.tag == .emscripten) {
        const len = @import("c.zig").em.em_js_file_load(path.ptr, //
            content.ptr, @intCast(content.len));
        if (len == 0) return error.FileNotFound;

        const value = @import("c.zig").em.my_add(1, 1);
        _ = value;

        return content[0..@as(usize, @intCast(len))];
    }
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const bytes = try file.readAll(content);
    return content[0..bytes];
}

pub fn saveAll(path: [:0]const u8, content: []const u8) !void {
    if (@import("builtin").target.os.tag == .emscripten) {
        return @import("c.zig").em.em_js_file_save(path.ptr, //
            content.ptr, @intCast(content.len));
    }

    const cwd = std.fs.cwd();

    if (std.fs.path.dirname(path)) |dir| {
        try cwd.makePath(dir);
    }

    var file = cwd.openFile(path, .{ .mode = .write_only }) //
        catch |err| switch (err) {
            error.FileNotFound => try cwd.createFile(path, .{}),
            else => return err,
        };
    defer file.close();

    try file.writeAll(content);
}

pub fn exit() void {
    sk.app.requestQuit();
}

pub fn isAnyRelease() bool {
    return input.anyRelease;
}

pub const File = assets.File;
pub const loadTexture = assets.loadTexture;
pub const playSound = audio.playSound;
pub const playMusic = audio.playMusic;
pub const stopMusic = audio.stopMusic;
pub const random = math.random;

pub const isKeyDown = input.isKeyDown;
pub const isAnyKeyDown = input.isAnyKeyDown;
pub const isKeyPress = input.isKeyPress;
pub const isAnyKeyPress = input.isAnyKeyPress;
pub const isKeyRelease = input.isKeyRelease;
pub const isAnyKeyRelease = input.isAnyKeyRelease;

pub const isMouseDown = input.isMouseDown;
pub const isMousePress = input.isMousePress;
pub const isMouseRelease = input.isMouseRelease;
pub const isAnyMouseRelease = input.isAnyMouseRelease;

pub const initFont = font.init;
