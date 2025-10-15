const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const SIZE: math.Vector2 = .init(32, 32);
const map = @import("map.zig");
const player = @import("player.zig");

const Animation = std.EnumArray(math.FourDirection, gfx.FrameAnimation);
pub const zon: []const Character = @import("zon/npc.zon");
var npcPaths: [15][:0]const u8 = blk: {
    var list: [15][:0]const u8 = undefined;
    for (&list, 1..) |*value, i| {
        value.* = std.fmt.comptimePrint("assets/pic/npc{:02}.png", .{i});
    }
    break :blk list;
};
var npcTextures: [npcPaths.len]gfx.Texture = undefined;
const frames: [2]gfx.Frame = .{
    .{ .area = .init(.init(0, 0), SIZE), .interval = 0.5 },
    .{ .area = .init(.init(32, 0), SIZE), .interval = 0.5 },
};
pub var dead: std.StaticBitSet(64) = .initEmpty();

const State = struct {
    index: u8,
    position: math.Vector2,
    facing: gfx.FourDirection = .down,
    animation: Animation,
    timer: window.Timer,
};

var npcBuffer: [12]State = undefined;
var npcArray: std.ArrayListUnmanaged(State) = undefined;

pub fn init() void {
    for (&npcTextures, &npcPaths) |*texture, path| {
        texture.* = gfx.loadTexture(path, .init(64, 128));
    }
    npcArray = .initBuffer(&npcBuffer);
}

pub fn enter() void {
    npcArray.clearRetainingCapacity();

    for (map.current.npcs) |id| {
        if (dead.isSet(id)) continue;
        const stop = zon[id].speed == 0;
        if (zon[id].progress < player.progress) continue;
        npcArray.appendAssumeCapacity(.{
            .index = id,
            .facing = if (stop) zon[id].facing else .random(),
            .position = .init(zon[id].x, zon[id].y),
            .animation = buildAnimation(npcTextures[zon[id].picture]),
            .timer = .init(math.randF32(3, 5)),
        });
    }
}

fn buildAnimation(texture: gfx.Texture) Animation {
    var animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(64, SIZE.x)));
    animation.set(.down, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.left, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.up, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.right, gfx.FrameAnimation.init(tex, &frames));

    return animation;
}

pub fn update(delta: f32) void {
    for (npcArray.items) |*npc| {
        const speed = zon[npc.index].speed * delta;
        if (npc.timer.isFinishedAfterUpdate(delta) and speed > 0) {
            npc.facing = .random();
            npc.timer = .init(math.randF32(3, 5));
        }

        npc.animation.getPtr(npc.facing).update(delta);
        const velocity: math.Vector2 = switch (npc.facing) {
            .down => .init(0, speed),
            .left => .init(-speed, 0),
            .up => .init(0, -speed),
            .right => .init(speed, 0),
        };

        // NPC 和地图的碰撞检测，只检测一半大小
        const offset = math.Vector2.init(8, 16);

        const pos = npc.position.add(offset);
        const area = math.Rect.init(pos, SIZE.scale(0.5));
        var newPosition = map.walkTo(area, velocity);
        // if (newPosition.approxEqual(pos)) {
        //     // 坐标相等，表示没有移动，撞墙了。
        //     const old = npc.facing;
        //     while (old == npc.facing) npc.facing = .random();
        //     npc.timer.reset();
        //     return;
        // }

        // 检测和角色的碰撞
        newPosition = newPosition.sub(offset);
        const collider = math.Rect.init(newPosition, SIZE);
        if (!collider.intersect(player.collider())) {
            npc.position = newPosition;
        }
    }
}

pub fn isCollision(collider: math.Rect) bool {
    for (npcArray.items) |npc| {
        const npcCollider = math.Rect.init(npc.position, SIZE);
        if (collider.intersect(npcCollider)) return true;
    }
    return false;
}

pub fn death(index: u16) void {
    dead.set(index);
    for (npcArray.items, 0..) |npc, i| {
        if (npc.index == index) {
            _ = npcArray.swapRemove(i);
            return;
        }
    }
}

pub fn talk(collider: math.Rect, facing: math.FourDirection) ?u8 {
    for (npcArray.items) |*npc| {
        if (zon[npc.index].enemy) continue;

        const npcCollider = math.Rect.init(npc.position, SIZE);
        if (collider.intersect(npcCollider)) {
            // 将 NPC 的面向调整到角色的反方向
            npc.facing = facing.opposite();
            const index: u8 = if (player.progress > 4) 1 else 0;
            return zon[npc.index].talks[index];
        }
    }
    return null;
}

pub fn battle(collider: math.Rect, facing: math.FourDirection) ?u8 {
    for (npcArray.items) |*npc| {
        if (!zon[npc.index].enemy) continue;
        // 战斗的时候，将敌人的碰撞范围扩大
        const pos = npc.position.sub(SIZE.scale(0.25));
        const area = math.Rect.init(pos, SIZE.scale(1.5));
        if (collider.intersect(area)) {
            // 将 NPC 的面向调整到角色的反方向
            npc.facing = facing.opposite();
            return npc.index;
        }
    }
    return null;
}

pub fn draw() void {
    for (npcArray.items) |npc| {
        const animation = npc.animation.getPtrConst(npc.facing);
        camera.draw(animation.currentTexture(), npc.position);
    }
}

pub fn drawTalk(actor: u8) void {

    // 头像
    camera.draw(photo(actor), .init(40, 400));

    // 名字
    const name = zon[actor].name;
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(name, .init(25, 445), nameColor);
}

pub fn photo(npcIndex: u16) gfx.Texture {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.subTexture(.init(.zero, SIZE));
}

pub fn battleTexture(npcIndex: u16) gfx.Texture {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.subTexture(.init(.init(0, SIZE.x), SIZE));
}

pub const Character = struct {
    enemy: bool = false,
    talks: []const u8 = &.{},
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: gfx.FourDirection = .down,
    // stats: u8,
    level: u16 = 1,
    // exp: u32,
    health: u16 = 0,
    // maxLift: u16,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    goods: []const u8 = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50, // 逃跑成功率
};
