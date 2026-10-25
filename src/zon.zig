const std = @import("std");
const zhu = @import("zhu");

const Animation = zhu.Animation;
const tiled = zhu.extend.tiled;

const NpcAnimation = struct {
    images: [15]zhu.graphics.ImageId,
    size: zhu.Vector2,
    frames: [4]Animation.Frames,
};

const Config = struct {
    player: []const Animation.Source,
    bomb: []const Animation.Source,
    npc: NpcAnimation,
    input: []const zhu.input.Bind,
};

pub const Facing = enum { down, left, up, right };

// 可持有、使用或交易的物品配置。
pub const Item = struct {
    key: []const u8,
    name: []const u8,
    icon: u8, // goods.png 中的图片格子
    about: []const u8 = &.{},
    money: u32 = 0,
    exp: i32 = 0,
    health: i32 = 0,
    attack: i32 = 0,
    defend: i32 = 0,

    pub const list: []const Item = @import("zon/item.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    // 根据稳定标识取得物品配置。
    pub fn get(key: Key) *const Item {
        return &list[@backingInt(key)];
    }
};

pub const Chest = struct {
    id: u16,
    item: ?Item.Key = null,

    pub const Place = struct {
        id: u16,
        tileIndex: u16,
    };

    pub const list: []const ?Chest = @import("zon/chest.zon");

    // 根据稳定 ID 取得宝箱配置。
    pub fn get(id: u16) *const Chest {
        return &list[id].?;
    }
};

pub const Actor = struct {
    const Animations = std.EnumArray(Key, []const Animation.Source);

    // 所有 NPC 共用相同的素材布局。
    const npcSources: [15][4]Animation.Source = blk: {
        var sources: [15][4]Animation.Source = undefined;
        for (config.npc.images, 0..) |imageId, imageIndex| {
            for (config.npc.frames, 0..) |frames, sourceIndex| {
                sources[imageIndex][sourceIndex] = .{
                    .imageId = imageId,
                    .size = config.npc.size,
                    .frames = frames,
                };
            }
        }
        break :blk sources;
    };

    // 编译期生成每个角色对应的动画配置。
    const animations: Animations = blk: {
        var result = Animations.initUndefined();
        result.set(.player, config.player);
        for (list[1..], 1..) |actor, index| {
            const key: Key = @fromBackingInt(@intCast(index));
            result.set(key, &npcSources[actor.picture]);
        }
        break :blk result;
    };

    key: []const u8,
    enemy: bool = false,
    dialogues: ?[2]u16 = null,
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: Facing = .down,
    level: u16 = 1,
    health: u16 = 0,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    moveProgress: ?u8 = null, // 达到该剧情进度后才能移动
    panicSpeed: ?f32 = null, // 慌乱时的移动速度
    goods: []const Item.Key = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50,

    pub const list: []const Actor = @import("zon/actor.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    pub fn get(key: Key) *const Actor {
        return &list[@backingInt(key)];
    }

    // 根据角色标识创建对应的地图动画。
    pub fn animation(key: Key) Animation {
        return .initSource(animations.get(key));
    }

    // 取得角色指定方向的第一帧图片。
    pub fn image(key: Key, facing: Facing) zhu.Image {
        const source = animations.get(key)[@backingInt(facing)];
        const atlas = zhu.assets.getImage(source.imageId).?;
        return atlas.sub(.init(source.frames[0].offset, source.size));
    }

    // 根据剧情进度取得角色当前使用的对话。
    pub fn talk(self: Actor, progress: u8) []const dialog.Line {
        const ids = self.dialogues.?;
        const index: usize = if (progress > 4) 1 else 0;
        return dialogues[ids[index]].lines;
    }

    // 根据剧情进度取得角色当前的移动速度。
    pub fn moveSpeed(self: Actor, progress: u8) f32 {
        if (progress > 4) return self.panicSpeed orelse self.speed;
        return self.speed;
    }
};

pub const dialog = struct {
    pub const Event = union(enum) {
        finish,
        openWeaponShop,
        openPotionShop,
        openSale,
        battle: Actor.Key,
        unlock: u8,
        showSwordTip,
        showEnding,
    };

    pub const Line = struct {
        actor: ?Actor.Key,
        content: []const u8 = &.{},
        event: ?Event = null,
    };

    // 一段完整的对话脚本。
    pub const Script = struct {
        id: u16,
        lines: []const Line,
    };
};

pub const dialogues: []const dialog.Script = @import("zon/talk.zon");
pub const config: Config = @import("zon/config.zon");
pub const input = zhu.input.bind(config.input);

pub const TileWindow = struct {
    grid: tiled.Grid = undefined,
    padding: u32 = 8,
    area: zhu.Rect = .init(.zero, .zero),
    vertices: std.ArrayList(zhu.batch.Vertex) = .empty,

    // 计算任意视口位置可能需要的最大顶点容量。
    pub fn maxVertexCount(self: TileWindow, layers: usize) usize {
        const viewSize = zhu.camera.viewport().size
            .div(self.grid.cellSize()).ceil().add(.one)
            .add(.square(@floatFromInt(self.padding * 2)));

        const size = viewSize.min(.xy(
            @floatFromInt(self.grid.width),
            @floatFromInt(self.grid.height),
        ));
        return @as(usize, @intFromFloat(size.x * size.y)) * layers;
    }

    // 视口超出旧范围时，保存并返回新的瓦片窗口。
    pub fn update(self: *TileWindow) bool {
        const viewport = zhu.camera.viewport();
        if (self.area.containsRect(viewport)) return false;

        const cell = self.grid.cellSize();
        const padding = cell.scale(@floatFromInt(self.padding));
        const min = viewport.min.div(cell).floor()
            .mul(cell).sub(padding);
        const max = viewport.max().div(cell).ceil()
            .mul(cell).add(padding);
        self.area = .fromMax(min, max);
        return true;
    }

    // 从整数图层和规则图片中重建窗口顶点。
    pub fn rebuildImage(
        self: *TileWindow,
        image: zhu.Image,
        layers: []const []const u16,
        grid: tiled.Grid,
    ) void {
        self.vertices.clearRetainingCapacity();
        const tileSize = self.grid.cellSize();
        const inset = grid.cellSize().sub(tileSize).scale(0.5);

        for (layers) |layer| {
            var cells = self.grid.cellsInRect(self.area);
            while (cells.next()) |index| {
                if (layer[index] == 0) continue;

                const pos = grid.indexToWorld(layer[index]).add(inset);
                self.appendVertex(
                    self.grid.indexToWorld(index),
                    image.sub(.init(pos, tileSize)),
                );
            }
        }
    }

    // 按传入顺序重建 Tiled 的瓦片层和图片层。
    pub fn rebuildTiled(
        self: *TileWindow,
        map: *const tiled.Map,
        layers: []const tiled.Layer,
    ) void {
        self.vertices.clearRetainingCapacity();
        for (layers) |layer| switch (layer.type) {
            .tile => self.appendTileLayer(map, layer),
            .image => self.appendImageLayer(layer),
            .object => {},
        };
    }

    fn appendTileLayer(
        self: *TileWindow,
        map: *const tiled.Map,
        layer: tiled.Layer,
    ) void {
        const grid = layer.grid(self.grid.cell);
        const area = self.area.move(layer.offset.neg());
        var cells = grid.cellsInRect(area);
        while (cells.next()) |index| {
            const gid = layer.data[index];
            if (gid == 0) continue;

            const image = map.getImage(gid) orelse continue;
            const position = grid.indexToWorld(index).add(layer.offset);
            self.appendVertex(position, image);
        }
    }

    fn appendImageLayer(self: *TileWindow, layer: tiled.Layer) void {
        const size = zhu.Vector2.xy(layer.width, layer.height);
        const rect = zhu.Rect.init(layer.offset, size);
        if (!self.area.intersect(rect)) return;

        const image = zhu.assets.getImage(layer.image).?
            .sub(.init(.zero, size));
        self.appendVertex(layer.offset, image);
    }

    fn appendVertex(
        self: *TileWindow,
        position: zhu.Vector2,
        image: zhu.Image,
    ) void {
        self.vertices.appendAssumeCapacity(.{
            .position = position,
            .layer = image.layer,
            .size = image.size,
            .uvRect = image.uvRect(),
        });
    }
};

pub const Map = struct {
    key: []const u8,
    grid: tiled.Grid,
    back: []const u16,
    ground: []const u16,
    object: []const u8,
    chests: []const Chest.Place = &.{},
    actors: []const Actor.Key = &.{},

    pub const list: []const Map = @import("zon/map.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    // 根据稳定标识取得地图配置。
    pub fn get(key: Key) *const Map {
        return &list[@backingInt(key)];
    }
};

pub const Portal = struct {
    pub const Gate = struct {
        // 当前进度必须大于该值才能通过。
        progress: u8,
        // 尚未达到开放条件时显示的对话。
        blockedDialogue: u16,
        // 正好达到条件时触发的剧情对话。
        reachedDialogue: ?u16 = null,
    };

    key: Key,
    target: Key,
    map: Map.Key,
    facing: Facing,
    gate: ?Gate = null,

    const source = @import("zon/portal.zon");
    pub const Key = zhu.enums.fromField(source, "key");
    pub const list: []const Portal = @import("zon/portal.zon");

    pub fn get(value: Key) *const Portal {
        return &list[@backingInt(value)];
    }
};

comptime {
    for (dialogues, 0..) |dialogue, id| {
        std.debug.assert(dialogue.id == id);
    }
    for (Chest.list, 0..) |chest, id| {
        if (chest) |value| std.debug.assert(value.id == id);
    }
    for (Portal.list) |portal| {
        if (portal.gate) |gate| {
            std.debug.assert(gate.blockedDialogue < dialogues.len);
            if (gate.reachedDialogue) |id| {
                std.debug.assert(id < dialogues.len);
            }
        }
    }
}

test "通过 key 查找角色配置" {
    try std.testing.expectEqualStrings("小飞刀", Actor.get(.player).name);
    try std.testing.expectEqualStrings(
        "小春春",
        Actor.get(.xiaoChunChun).name,
    );
    try std.testing.expectEqualStrings("公  主", Actor.get(.gongZhu).name);
}
