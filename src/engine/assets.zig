const std = @import("std");

const sk = @import("sokol");
const c = @import("c.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    sk.fetch.setup(.{ .logger = .{ .func = sk.log.func } });
}

pub fn deinit() void {
    Texture.cache.deinit(allocator);
    Sound.cache.deinit(allocator);
    Music.deinit();
    File.deinit();
    sk.fetch.shutdown();
}

pub fn loadTexture(path: [:0]const u8, size: gfx.Vector) gfx.Texture {
    return Texture.load(path, size);
}

pub fn loadSound(path: [:0]const u8, loop: bool) *audio.Sound {
    return Sound.load(path, loop);
}

pub fn loadMusic(path: [:0]const u8, loop: bool) *audio.Music {
    return Music.load(path, loop);
}

pub const Texture = struct {
    var cache: std.StringHashMapUnmanaged(gfx.Texture) = .empty;

    pub fn load(path: [:0]const u8, size: gfx.Vector) gfx.Texture {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const view = sk.gfx.allocView();
        _ = File.load(path, view.id, handler);

        entry.value_ptr.* = .{ .view = view, .area = .init(.zero, size) };
        return entry.value_ptr.*;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const image = c.stbImage.loadFromMemory(data) catch unreachable;
        defer c.stbImage.unload(image);
        const texture = cache.getPtr(response.path).?;

        sk.gfx.initView(texture.view, .{ .texture = .{
            .image = sk.gfx.makeImage(.{
                .width = image.width,
                .height = image.height,
                .data = init: {
                    var imageData = sk.gfx.ImageData{};
                    imageData.mip_levels[0] = sk.gfx.asRange(image.data);
                    break :init imageData;
                },
            }),
        } });
        return &.{};
    }
};

const Sound = struct {
    var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

    fn load(path: [:0]const u8, loop: bool) *audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr;

        const index = audio.allocSoundBuffer();
        entry.value_ptr.* = .{ .loop = loop, .handle = index };
        _ = File.load(path, index, handler);
        return entry.value_ptr;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const stbAudio = c.stbAudio.loadFromMemory(data) catch unreachable;
        defer c.stbAudio.unload(stbAudio);
        const info = c.stbAudio.getInfo(stbAudio);

        var sound = cache.getPtr(response.path).?;

        sound.channels = @intCast(info.channels);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);

        sound.state = .playing;
        audio.sounds[response.index] = sound.*;
        return @ptrCast(sound.source);
    }
};

const Music = struct {
    var cache: std.StringHashMapUnmanaged(audio.Music) = .empty;

    fn load(path: [:0]const u8, loop: bool) *audio.Music {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr;

        _ = File.load(path, 0, handler);
        entry.value_ptr.* = .{ .loop = loop };
        return entry.value_ptr;
    }

    fn handler(response: Response) []const u8 {
        const data = allocator.dupe(u8, response.data) catch unreachable;
        const stbAudio = c.stbAudio.loadFromMemory(data) catch unreachable;

        const value = cache.getPtr(response.path).?;
        value.source = stbAudio;
        value.state = .playing;
        audio.music = value.*;
        return data;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| c.stbAudio.unload(value.source);
        cache.deinit(allocator);
    }
};

var loadingBuffer: [5 * 1024 * 1024]u8 = undefined;

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    allocator: std.mem.Allocator = undefined,
    index: usize = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};

pub const File = struct {
    const FileState = enum { init, loading, loaded, handled };
    const Handler = *const fn (Response) []const u8;

    const FileCache = struct {
        state: FileState = .init,
        index: usize,
        data: []const u8 = &.{},
        handler: Handler = undefined,
    };

    var cache: std.StringHashMapUnmanaged(FileCache) = .empty;

    pub fn load(path: [:0]const u8, index: usize, handler: Handler) *FileCache {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr;

        entry.value_ptr.* = .{ .index = index, .handler = handler };

        std.log.info("loading {s}", .{path});
        const buffer = sk.fetch.asRange(&loadingBuffer);
        _ = sk.fetch.send(.{
            .path = path,
            .callback = callback,
            .buffer = buffer,
        });

        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.c) void {
        const res = responses[0];
        if (res.failed) {
            std.debug.panic("assets load failed, path: {s}", .{res.path});
        }

        const path = std.mem.span(res.path);
        std.log.info("loaded from: {s}", .{path});

        const value = cache.getPtr(path) orelse return;
        const data = @as([*]const u8, @ptrCast(res.data.ptr));
        const response: Response = .{
            .allocator = allocator,
            .index = value.index,
            .path = path,
            .data = data[0..res.data.size],
        };

        value.state = .loaded;
        value.data = value.handler(response);
        value.state = .handled;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.data);
        cache.deinit(allocator);
    }
};
