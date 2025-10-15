const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const titleScene = @import("title.zig");
const worldScene = @import("world.zig");
const battleScene = @import("battle.zig");

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .title;
var toSceneType: SceneType = .title;

var isHelp: bool = true;
var isDebug: bool = false;

pub fn init() void {
    window.initFont(.{
        .font = @import("zon/font.zon"),
        .texture = gfx.loadTexture("assets/font.png", .init(960, 960)),
    });

    camera.frameStats(true);

    camera.init(2000);

    titleScene.init();
    worldScene.init();
    battleScene.init();

    sceneCall("enter", .{});
}

pub fn changeScene(sceneType: SceneType) void {
    toSceneType = sceneType;
    fadeOut(doChangeScene);
}

pub fn changeMap() void {
    fadeOut(worldScene.changeMap);
}

fn doChangeScene() void {
    sceneCall("exit", .{});
    currentSceneType = toSceneType;
    sceneCall("enter", .{});
}

pub fn update(delta: f32) void {
    window.keepAspectRatio();
    if (window.isKeyRelease(.H)) isHelp = !isHelp;
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (fadeTimer) |*timer| {
        // 存在淡入淡出效果，地图和角色暂时不更新。
        if (timer.isRunningAfterUpdate(delta)) return;
        if (isFadeIn) {
            fadeTimer = null;
        } else {
            if (fadeOutEndCallback) |callback| callback();
            isFadeIn = true;
            timer.restart();
        }
        return;
    }
    sceneCall("update", .{delta});
}

pub fn draw() void {
    camera.beginDraw();
    defer camera.endDraw();

    sceneCall("draw", .{});

    // 将文字先绘制上，后面的淡入淡出才会生效。
    camera.flushTextureAndText();
    if (fadeTimer) |*timer| {
        camera.mode = .local;
        defer camera.mode = .world;
        const percent = timer.elapsed / timer.duration;
        const alpha = if (isFadeIn) 1 - percent else percent;
        camera.drawRect(.init(.zero, window.logicSize), .{ .w = alpha });
        camera.flushTexture();
    }
    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
        \\作者：jiangbo4444
    ;
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
        \\角色：{d:.2}，{d:.2}
        \\相机：{d:.2}，{d:.2}
    ;

    const stats = camera.queryFrameStats();
    const player = @import("player.zig");
    const text = zhu.format(&buffer, format, .{
        @tagName(camera.queryBackend()),
        window.frameRate,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        player.position.x,
        player.position.y,
        camera.position.x,
        camera.position.y,
    });

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var fadeTimer: ?window.Timer = null;
var isFadeIn: bool = false;
var fadeOutEndCallback: ?*const fn () void = null;

pub fn fadeIn() void {
    isFadeIn = true;
    fadeTimer = .init(1);
}

pub fn fadeOut(callback: ?*const fn () void) void {
    isFadeIn = false;
    fadeTimer = .init(1);
    fadeOutEndCallback = callback;
}

pub fn deinit() void {
    sceneCall("deinit", .{});
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
        .battle => window.call(battleScene, function, args),
    }
}
