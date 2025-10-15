const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const world = @import("world.zig");

var background: gfx.Texture = undefined;
var menuBackground: gfx.Texture = undefined;

var displayHeader: bool = false;
var displayTimer: window.Timer = .init(0.08);
var textIndex: usize = 0;

pub fn init() void {
    background = gfx.loadTexture("assets/pic/title.png", .init(640, 480));
    const path = "assets/pic/mainmenu2.png";
    menuBackground = gfx.loadTexture(path, .init(150, 200));
}

pub fn enter() void {
    menu.active = 4;
    window.playMusic("assets/voc/title.ogg");
    displayHeader = false;
    textIndex = 0;
    scene.fadeIn();
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    if (displayHeader) return updateHeader(delta);

    const menuEvent = menu.update();
    if (menuEvent) |event| menuSelected(event);

    if (window.isAnyKeyRelease(&.{ .Q, .ESCAPE })) {
        menu.active = 4;
    }
}

fn menuSelected(index: u8) void {
    switch (index) {
        0 => scene.fadeOut(struct {
            fn call() void {
                displayHeader = true;
            }
        }.call),
        1 => menu.active = 5,
        2 => window.exit(),
        3, 4, 5, 6, 7 => |event| {
            world.load(event) catch return;
            world.back = .battle;
            scene.changeScene(.world);
        },
        8 => menu.active = 4,
        else => unreachable(),
    }
}

pub fn draw() void {
    if (displayHeader) return drawHeader();
    camera.draw(background, .zero);

    if (menu.current().background) {
        camera.draw(menuBackground, menu.current().position);
    }
    menu.draw();
}

fn updateHeader(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER }) or
        window.isMouseRelease(.LEFT))
    {
        scene.changeScene(.world);
        return;
    }

    if (displayTimer.isFinishedAfterUpdate(delta)) {
        if (textIndex >= text.len) return;
        const len = std.unicode.utf8ByteSequenceLength(text[textIndex]);
        textIndex += len catch unreachable;
        displayTimer.reset();
    }
}

const text =
    \\　　在很久很久以前，白云城的居民过着富足而安定的生活。不过
    \\一场巨大的灾难即将降临到这里……
    \\　　一天，我们故事的主人翁'小飞刀'一觉醒来，故事就从这里开
    \\始……　　[按回车键继续]
;

pub fn drawHeader() void {
    camera.drawText(text[0..textIndex], .init(40, 100));
}
