const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const item = @import("item.zig");
const npc = @import("npc.zig");

const SIZE = 32;
const TILE_SIZE: math.Vector2 = .init(SIZE, SIZE);

var texture: gfx.Texture = undefined;
var rowTiles: usize = 0;

const Chest = struct { tileIndex: u16, pickupIndex: u16 };

const Map = struct {
    width: u16,
    height: u16,
    back: []const u16,
    ground: []const u16,
    object: []const u8,
    chests: []const Chest = &.{},
    npcs: []const u8 = &.{},
};

const Link = struct {
    player: gfx.Vector = .zero,
    mapId: u8 = 0,
    progress: u8 = 0,
};
const zon: []const Map = @import("zon/map.zon");
pub const links: []const Link = @import("zon/link.zon");
pub var linkIndex: u8 = 4;
pub var current: *const Map = undefined;
pub var size: math.Vector2 = undefined;

var vertexBuffer: [2000]camera.Vertex = undefined;
var vertexArray: std.ArrayListUnmanaged(camera.Vertex) = undefined;
var backgroundIndex: usize = undefined;

pub fn init() void {
    vertexArray = .initBuffer(&vertexBuffer);
    texture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));
    rowTiles = @intFromFloat(@divExact(texture.size().x, 32));
}

pub fn enter() math.Vector2 {
    const link = links[linkIndex];
    current = &zon[link.mapId];
    const x: f32 = @floatFromInt(current.width);
    const y: f32 = @floatFromInt(current.height);
    size = math.Vector2.init(x, y).scale(SIZE);

    vertexArray.clearRetainingCapacity();

    buildVertexBuffer(current.back);
    buildVertexBuffer(current.ground);
    backgroundIndex = vertexArray.items.len;
    for (current.chests) |chest| {
        if (item.picked.isSet(chest.pickupIndex))
            appendVertex(302, chest.tileIndex)
        else
            appendVertex(301, chest.tileIndex);
    }

    return link.player;
}

fn buildVertexBuffer(tiles: []const u16) void {
    for (tiles, 0..) |tileIndex, index| {
        if (tileIndex != 0) appendVertex(tileIndex, index);
    }
}

fn appendVertex(tileIndex: usize, index: usize) void {
    vertexArray.appendAssumeCapacity(buildVertex(tileIndex, index));
}

fn buildVertex(tileIndex: usize, index: usize) camera.Vertex {
    const row: f32 = @floatFromInt(tileIndex / rowTiles);
    const col: f32 = @floatFromInt(tileIndex % rowTiles);
    const pos = math.Vector2.init(col, row).mul(TILE_SIZE);

    const tile = texture.subTexture(.init(pos, TILE_SIZE));
    return camera.Vertex{
        .position = getPositionFromIndex(index).toVector3(0),
        .size = TILE_SIZE,
        .texture = tile.area.toVector4(),
    };
}

fn getPositionFromIndex(index: usize) gfx.Vector {
    const row: f32 = @floatFromInt(index / current.width);
    const col: f32 = @floatFromInt(index % current.width);
    return math.Vector.init(col, row).mul(TILE_SIZE);
}

pub fn talk(position: gfx.Vector, direction: math.FourDirection) ?u16 {
    const index: i32 = @intCast(positionIndex(position));
    const talkIndex: i32 = switch (direction) {
        .down => index + current.width,
        .left => index - 1,
        .right => index + 1,
        .up => index - current.width,
    };

    if (talkIndex < 0 or talkIndex > current.object.len) return null;
    const talkObject = current.object[@intCast(talkIndex)];
    if (talkObject != 2) return null;

    for (current.chests) |chest| {
        if (talkIndex != chest.tileIndex) continue;
        // 宝箱已经被打开，不需要处理任何东西
        if (item.picked.isSet(chest.pickupIndex)) return null;
        return @intCast(chest.pickupIndex);
    }
    unreachable;
}

pub fn openChest(pickIndex: usize) void {
    // back 和 ground 已经填充的顶点不需要修改，修改宝箱的顶点

    for (current.chests, 0..) |chest, index| {
        if (pickIndex != chest.pickupIndex) continue;

        item.picked.set(pickIndex);
        const vertex = buildVertex(302, chest.tileIndex);
        vertexArray.items[backgroundIndex + index] = vertex;
        return;
    }
    unreachable;
}

pub fn positionIndex(position: gfx.Vector) usize {
    const x: u16 = @intFromFloat(@floor(position.x / 32));
    const y: u16 = @intFromFloat(@floor(position.y / 32));
    return x + y * current.width;
}

pub fn getObject(index: usize) u8 {
    return current.object[index];
}

pub fn walkTo(area: math.Rect, velocity: math.Vector2) math.Vector2 {
    if (velocity.x == 0 and velocity.y == 0) return area.min;
    return .init(walkToX(area, velocity.x), walkToY(area, velocity.y));
}

fn walkToX(area: math.Rect, velocity: f32) f32 {
    const min = area.min.addX(velocity);
    if (min.x < 0) return 0;
    const max = area.max().addX(velocity);
    if (max.x > size.x) return size.x - 0.1 - area.size.x;

    if (velocity > 0) {
        if (canWalk(.init(max.x, min.y)) and canWalk(max)) return min.x;
        const index = positionIndex(max) % current.width;
        // 把左上角的位置放到图块的左边缘
        const x: f32 = @floatFromInt(index * SIZE);
        // 平移加容忍，将右边放到图块的左边缘
        return x - area.size.x - 0.1;
    } else {
        if (canWalk(min) and canWalk(.init(min.x, max.y))) return min.x;
        const index = 1 + positionIndex(min) % current.width;
        return @floatFromInt(index * SIZE);
    }
}

fn walkToY(area: math.Rect, velocity: f32) f32 {
    const min = area.min.addY(velocity);
    if (min.y < 0) return 0;
    const max = area.max().addY(velocity);
    if (max.y > size.y) return size.y - 0.1 - area.size.y;

    if (velocity > 0) {
        if (canWalk(.init(min.x, max.y)) and canWalk(max)) return min.y;
        const index = positionIndex(max) / current.width;
        const y: f32 = @floatFromInt(index * SIZE);
        return y - area.size.y - 0.1;
    } else {
        if (canWalk(min) and canWalk(.init(max.x, min.y))) return min.y;
        const index = 1 + positionIndex(min) / current.width;
        return @floatFromInt(index * SIZE);
    }
}

fn canWalk(position: math.Vector2) bool {
    if (position.x < 0 or position.y < 0) return false;
    if (position.x > size.x or position.y > size.y) return false;
    const index = positionIndex(position);
    if (index > current.object.len) return false;
    // 场景切换的图块也应该能通过
    return current.object[index] == 0 or current.object[index] > 4;
}

pub fn draw() void {
    camera.drawVertices(texture, vertexArray.items);
}
