const std = @import("std");

const zhu = @import("zhu");
const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const item = @import("item.zig");
const map = @import("map.zig");
const npc = @import("npc.zig");
const world = @import("world.zig");

const Animation = std.EnumArray(math.FourDirection, gfx.FrameAnimation);

const name = "小飞刀";
const MOVE_SPEED = 100;
pub const SIZE: math.Vector = .init(16, 16);
var texture: gfx.Texture = undefined;
var animation: Animation = undefined;

var facings: std.EnumArray(math.FourDirection, u64) = undefined;
pub var facing: math.FourDirection = .down;
pub var position: math.Vector = undefined;

pub var money: u32 = 50; // 金钱
pub var items: [16]u8 = undefined;
pub var itemIndex: u8 = 0;

pub var level: u16 = 1; //等级
pub var exp: u16 = 0; //经验
const maxExp = 100; //经验最大值
pub var health: u16 = 50; //生命
pub var maxHealth: u16 = 50; //生命最大值
pub var attack: u16 = 10; //攻击
pub var defend: u16 = 10; //防御
pub var speed: u16 = 8; //速度
pub var progress: u8 = 1; //进度

var bgTexture: gfx.Texture = undefined;

const frames: [3]gfx.Frame = .{
    .{ .area = .init(.init(0, 0), .init(32, 48)), .interval = 0.15 },
    .{ .area = .init(.init(32, 0), .init(32, 48)), .interval = 0.15 },
    .{ .area = .init(.init(64, 0), .init(32, 48)), .interval = 0.15 },
};

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
    bgTexture = gfx.loadTexture("assets/pic/sbar.png", .init(420, 320));

    animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(96, 48)));
    animation.set(.down, gfx.FrameAnimation.init(tex, &frames));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.left, gfx.FrameAnimation.init(tex, &frames));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.right, gfx.FrameAnimation.init(tex, &frames));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.up, gfx.FrameAnimation.init(tex, &frames));

    @memset(&items, 0);
}

pub fn enter(playerPosition: math.Vector2) void {
    position = playerPosition;
    cameraLookAt();
}

pub fn exit() void {}

pub fn update(delta: f32) void {

    // 角色移动和碰撞检测
    const dir = updateFacing();
    if (dir.x == 0 and dir.y == 0) return; // 没有移动
    animation.getPtr(facing).update(delta);

    const velocity = dir.normalize().scale(MOVE_SPEED).scale(delta);

    const area = math.Rect.init(position, SIZE);
    if (npc.isCollision(area.move(velocity))) return;

    position = map.walkTo(area, velocity);
    // 相机跟踪
    cameraLookAt();
}

fn updateFacing() math.Vector2 {
    const count = window.frameCount();
    var dir = math.Vector.zero;

    if (window.isAnyKeyDown(&.{ .UP, .W })) {
        dir.y -= 1;
        if (facings.get(.up) == 0) facings.set(.up, count);
    } else facings.set(.up, 0);

    if (window.isAnyKeyDown(&.{ .DOWN, .S })) {
        dir.y += 1;
        if (facings.get(.down) == 0) facings.set(.down, count);
    } else facings.set(.down, 0);

    if (window.isAnyKeyDown(&.{ .LEFT, .A })) {
        dir.x -= 1;
        if (facings.get(.left) == 0) facings.set(.left, count);
    } else facings.set(.left, 0);

    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) {
        dir.x += 1;
        if (facings.get(.right) == 0) facings.set(.right, count);
    } else facings.set(.right, 0);

    var max: u64 = 0;
    var iterator = facings.iterator();
    while (iterator.next()) |entry| {
        if (entry.value.* > max) {
            max = entry.value.*;
            facing = entry.key;
        }
    }
    return dir;
}

pub fn openItem() bool {
    if (needDrawInfo and window.isAnyRelease()) needDrawInfo = false;
    itemIndex = item.update(items.len, itemIndex);

    if (items[itemIndex] == 0) return false;

    if (window.isAnyKeyRelease(&.{ .LEFT_CONTROL, .F })) {
        //  使用物品
        // TODO 绘制状态
        const usedItem = item.zon[items[itemIndex]];

        addStatusValue(&exp, usedItem.exp);
        addStatusValue(&health, usedItem.health);
        addStatusValue(&attack, usedItem.attack);
        addStatusValue(&defend, usedItem.defend);
        if (health > maxHealth) health = maxHealth;
        items[itemIndex] = 0;
        needDrawInfo = true;

        return true;
    } else if (window.isKeyRelease(.G)) {
        // 丢弃物品
        items[itemIndex] = 0;
    }

    return false;
}

fn addStatusValue(value: *u16, add: i32) void {
    const tmp = @as(i32, @intCast(value.*)) + add;
    value.* = if (tmp < 0) 0 else @intCast(tmp);
}

var sellItemIndex: u16 = 0;
pub fn sellItem() bool {
    if (sellItemIndex != 0) {
        if (window.isAnyRelease()) sellItemIndex = 0;
        return false;
    }

    itemIndex = item.update(items.len, itemIndex);

    if (items[itemIndex] == 0) return false;

    if (window.isAnyKeyRelease(&.{ .LEFT_CONTROL, .F })) {
        // 卖出物品
        sellItemIndex = items[itemIndex];
        const usedItem = item.zon[sellItemIndex];
        money += usedItem.money / 2;
        items[itemIndex] = 0;
        world.tip = "这东西归别人了！";
        return true;
    }
    return false;
}

pub fn cameraLookAt() void {
    const half = window.logicSize.scale(0.5);
    const max = map.size.sub(window.logicSize);
    camera.position = position.sub(half).clamp(.zero, max);
}

pub fn collider() math.Rect {
    return math.Rect.init(position, SIZE);
}

pub fn talkCollider() math.Rect {
    return switch (facing) {
        .up => .init(position.addXY(-3, -28), .init(20, 20)),
        .down => .init(position.addXY(-3, 20), .init(20, 20)),
        .left => .init(position.addXY(-28, -10), .init(20, 20)),
        .right => .init(position.addXY(20, -10), .init(20, 20)),
    };
}

pub fn addItem(itemId: u8) bool {
    for (&items) |*value| {
        if (value.* == 0) {
            value.* = itemId;
            return true;
        }
    }
    return false;
}

pub fn isLevelUp() bool {
    return exp >= maxExp;
}

pub fn levelUp() void {
    level += exp / maxExp;
    maxHealth += exp / maxExp * 30;
    attack += exp / maxExp * 1;
    defend += exp / maxExp * 1;
    health += (maxHealth - health) / 2;
    exp %= maxExp;
    health = maxHealth;
}

pub fn draw() void {
    const current = animation.get(facing);
    camera.draw(current.currentTexture(), position.addXY(-10, -28));

    // camera.debugDraw(.init(position, SIZE));
}

pub fn drawTalk() void {

    // 头像
    camera.draw(photo(), .init(35, 396));

    // 名字
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(name, .init(25, 445), nameColor);
}

pub fn photo() gfx.Texture {
    const down = animation.get(.down);
    return down.texture.subTexture(down.frames[0].area);
}

pub fn battleTexture() gfx.Texture {
    const right = animation.get(.right);
    return right.texture.subTexture(right.frames[0].area);
}

pub fn drawStatus() void {
    const pos = gfx.Vector.init(120, 90);
    // 背景
    camera.draw(bgTexture, pos.addXY(-10, -10));

    // 头像
    const down = animation.get(.down);
    const tex = down.texture.subTexture(down.frames[0].area);
    camera.draw(tex, pos.addXY(10, 10));
    drawInfo(pos, 30);
}

fn drawInfo(pos: math.Vector2, offsetY: f32) void {
    // 等级
    var y = 22 + offsetY;
    camera.drawColorText("等级：", pos.addXY(122, y), .black);
    camera.drawText("等级：", pos.addXY(120, y - 2));
    camera.drawColorNumber(level, pos.addXY(232, y), .black);
    camera.drawNumber(level, pos.addXY(230, y - 2));

    // 经验
    y += offsetY;
    camera.drawColorText("经验：", pos.addXY(122, y), .black);
    camera.drawText("经验：", pos.addXY(120, y - 2));
    var buffer: [30]u8 = undefined;
    const expStr = zhu.format(&buffer, "{d}/{d}", .{ exp, maxExp });
    camera.drawColorText(expStr, pos.addXY(232, y), .black);
    camera.drawText(expStr, pos.addXY(230, y - 2));

    // 生命
    y += offsetY;
    camera.drawColorText("生命：", pos.addXY(122, y), .black);
    camera.drawText("生命：", pos.addXY(120, y - 2));
    const healthStr = zhu.format(&buffer, "{d}/{d}", .{ health, maxHealth });
    camera.drawColorText(healthStr, pos.addXY(232, y), .black);
    camera.drawText(healthStr, pos.addXY(230, y - 2));

    // 攻击
    y += offsetY;
    camera.drawColorText("攻击：", pos.addXY(122, y), .black);
    camera.drawText("攻击：", pos.addXY(120, y - 2));
    camera.drawColorNumber(attack, pos.addXY(232, y), .black);
    camera.drawNumber(attack, pos.addXY(230, y - 2));

    // 防御
    y += offsetY;
    camera.drawColorText("防御：", pos.addXY(122, y), .black);
    camera.drawText("防御：", pos.addXY(120, y - 2));
    camera.drawColorNumber(defend, pos.addXY(232, y), .black);
    camera.drawNumber(defend, pos.addXY(230, y - 2));

    // 速度
    y += offsetY;
    camera.drawColorText("速度：", pos.addXY(122, y), .black);
    camera.drawText("速度：", pos.addXY(120, y - 2));
    camera.drawColorNumber(speed, pos.addXY(232, y), .black);
    camera.drawNumber(speed, pos.addXY(230, y - 2));

    // 金币
    y += offsetY;
    camera.drawColorText("金币：", pos.addXY(122, y), .black);
    camera.drawColorText("金币：", pos.addXY(120, y - 2), .yellow);
    camera.drawColorNumber(money, pos.addXY(232, y), .black);
    camera.drawColorNumber(money, pos.addXY(230, y - 2), .yellow);
}

var needDrawInfo: bool = false;
pub fn drawOpenItem() void {
    item.draw(&items, itemIndex);

    if (needDrawInfo) {
        camera.drawColorText("现在的状态：", .init(272, 92), .black);
        camera.drawColorText("现在的状态：", .init(270, 90), .yellow);
        drawInfo(.init(120, 73), 20);
    }

    var buffer: [20]u8 = undefined;
    // 金币，操作说明
    camera.drawText("（金=", item.position.addXY(10, 270));
    const moneyStr = zhu.format(&buffer, "{d}）", .{money});
    camera.drawText(moneyStr, item.position.addXY(60, 270));
    const text = " F=使用  G=丢弃  ESC=退出";
    camera.drawText(text, item.position.addXY(118, 270));
}

pub fn drawSellItem() void {
    item.draw(&items, itemIndex);

    var buffer: [50]u8 = undefined;
    if (sellItemIndex != 0) {
        const itemInfo = item.zon[sellItemIndex];
        const sellTip = zhu.format(&buffer, "卖掉[{s}]得到：{d}", .{
            itemInfo.name,
            itemInfo.money / 2,
        });
        camera.drawColorText(sellTip, item.position.addXY(102, 110), .black);
        camera.drawText(sellTip, item.position.addXY(100, 108));
    }

    camera.drawText("（金=", item.position.addXY(10, 270));
    const moneyStr = zhu.format(&buffer, "{d}）", .{money});
    camera.drawText(moneyStr, item.position.addXY(60, 270));
    const text = "CTRL=卖出  ESC=退出";
    camera.drawText(text, item.position.addXY(118, 270));
}
