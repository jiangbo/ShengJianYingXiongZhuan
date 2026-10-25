const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 4096);
    // 运行时窗口图标使用米白底角色图。
    zhu.window.useWindowIcon("icon.png");
    // 音频输出与生成的 OGG 使用相同采样率。
    zhu.audio.init(&soundBuffer, .{ .sample_rate = 11025 });
    zhu.assets.loadAtlas(@import("zon/atlas.zon"), .nearest);
    zhu.batch.init(vertexBuffer, &commandBuffer);

    zhu.text.msdf.init(@import("zon/font.zon"));
    zhu.text.changeFontSize(18);

    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw();
    zhu.batch.useTarget(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit();
    allocator.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    // 初始化引擎和应用存储，再启动窗口。
    zhu.init(initInfo);
    zhu.extend.storage.init(initInfo, "sjyxz");
    zhu.window.run(.{
        .title = "英雄救美",
        .size = .xy(640, 480),
        .scaleEnum = .fit,
    });
}

test "vector" {
    const value = zhu.Vector2.xy(1, 0);
    try std.testing.expectEqual(@as(f32, 1), value.x);
}
