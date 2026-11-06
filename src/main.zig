const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

// 合批命令使用固定缓冲区，由应用持有。
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    // 仅在渲染时对齐相机，逻辑位置保留小数。
    zhu.camera.roundPosition = true;
    // 运行时窗口图标使用米白底角色图。
    zhu.window.useWindowIcon("icon.png");
    // 音频输出与生成的 OGG 使用相同采样率。
    zhu.audio.init(&soundBuffer, .{ .sample_rate = 11025 });
    // 图片和字形共用纹理数组，预留两层存放字形。
    const atlas = zhu.assets.atlas.load(@import("zon/atlas.zon"), 2, .nearest);
    zhu.batch.init(&commandBuffer);

    zhu.text.init(.{ .size = 18, .atlas = atlas });

    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(_: zhu.Allocator) void {
    scene.deinit();
    zhu.text.dynamic.deinit();
}

pub fn main(initInfo: std.process.Init) void {
    // 初始化引擎和应用存储，再启动窗口。
    zhu.init(initInfo);
    zhu.extend.storage.init(initInfo, "sjyxz");
    zhu.window.run("英雄救美", .xy(640, 480), .{
        .scaleEnum = .fit,
    });
}

test "vector" {
    const value = zhu.Vector2.xy(1, 0);
    try std.testing.expectEqual(@as(f32, 1), value.x);
}
