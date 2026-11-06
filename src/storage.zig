const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const zon = @import("zon.zig");

const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Position = component.Position;
const Tip = component.event.Tip;

// 已经死亡、地图重建后不再创建的 NPC。
pub const DeadActors = std.EnumSet(zon.Actor.Key);

// 已经开启、地图重建后保持开启的宝箱。
pub const OpenedChests = std.StaticBitSet(zon.Chest.list.len);

// 玩家参与战斗和成长的数值。
pub const Stats = struct {
    level: u16 = 1, // 等级
    exp: u16 = 0, // 经验
    health: i32 = 50, // 生命
    maxHealth: i32 = 50, // 最大生命
    attack: u16 = 10, // 攻击
    defend: u16 = 10, // 防御
    agility: u16 = 8, // 敏捷

    // 使用当前经验升级，返回是否发生升级。
    pub fn levelUp(self: *Stats) bool {
        if (self.exp < 100) return false;

        const levelCount = self.exp / 100;
        self.level += levelCount;
        self.maxHealth += @as(i32, @intCast(levelCount)) * 30;
        self.attack += levelCount;
        self.defend += levelCount;
        self.exp %= 100;
        self.health = self.maxHealth;
        return true;
    }
};

// 玩家已经越过的剧情进度。
pub const Progress = struct { value: u8 = 1 };

// 玩家持有的金钱和物品。
pub const Inventory = struct {
    money: u32 = 50, // 金钱
    items: [16]?zon.Item.Key = @splat(null), // 物品

    // 将物品放入第一个空位。
    pub fn add(self: *Inventory, key: zon.Item.Key) bool {
        for (&self.items) |*value| {
            if (value.* != null) continue;
            value.* = key;
            return true;
        }
        return false;
    }
};

// 切换地图时保留的长期数据类型。
pub const keep = .{
    DeadActors,
    OpenedChests,
    Progress,
    Stats,
    Inventory,
};

// 存档中的当前地图和玩家位置。
pub const Location = struct {
    map: zon.Map.Key,
    position: zhu.Vector2,
    facing: Facing,
};

// 存档的完整结构。
const Record = struct {
    location: Location,
    progress: Progress = .{},
    stats: Stats = .{},
    inventory: Inventory = .{},
    openedChests: OpenedChests = .empty,
    deadActors: DeadActors = .empty,
};

// 重置新游戏使用的长期状态。
pub fn reset(world: *ecs.World) void {
    world.addResource(DeadActors.empty);
    world.addResource(OpenedChests.empty);
    world.addResource(Progress{});
    world.addResource(Stats{});
    world.addResource(Inventory{});
}

// 检查指定槽位是否已有存档。
pub fn exists(slot: u8) bool {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    return zhu.extend.storage.exists(path);
}

// 读取存档并恢复跨地图长期状态。
pub fn load(world: *ecs.World, slot: u8) ?Location {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    var data: [512]u8 = undefined;
    const bytes = zhu.extend.storage.readBuffer(path, &data) catch |err| {
        std.log.err("load {s} failed: {}", .{ path, err });
        return null;
    };
    const record = readRecord(bytes) catch |err| {
        std.log.err("load {s} failed: {}", .{ path, err });
        return null;
    };
    world.addResource(record.progress);
    world.addResource(record.stats);
    world.addResource(record.inventory);
    world.addResource(record.openedChests);
    world.addResource(record.deadActors);

    return record.location;
}

// 收集玩家位置和长期状态并写入存档。
pub fn save(world: *ecs.World, slot: u8) void {
    const player = world.getIdentityEntity(Player).?;
    const record: Record = .{
        .location = .{
            .map = world.get(player, zon.Map.Key).?,
            .position = world.get(player, Position).?,
            .facing = world.get(player, Facing).?,
        },
        .progress = world.getResourcePtr(Progress).?.*,
        .stats = world.getResourcePtr(Stats).?.*,
        .inventory = world.getResourcePtr(Inventory).?.*,
        .openedChests = world.getResourcePtr(OpenedChests).?.*,
        .deadActors = world.getResourcePtr(DeadActors).?.*,
    };
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    var data: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&data);
    writeRecord(&writer, record) catch unreachable;
    zhu.extend.storage.writeAll(path, writer.buffered()) catch |err| {
        std.log.err("save {s} failed: {}", .{ path, err });
        world.addEvent(Tip{ .text = "保存失败" });
    };
}

// 数值使用小端序，物品和角色使用配置中的枚举编号。
fn writeRecord(writer: *std.Io.Writer, record: Record) !void {
    try writer.writeAll("SJY1");
    try writer.writeByte(@intCast(@backingInt(record.location.map)));
    try writer.writeInt(u32, @bitCast(record.location.position.x), .little);
    try writer.writeInt(u32, @bitCast(record.location.position.y), .little);
    try writer.writeByte(@intCast(@backingInt(record.location.facing)));
    try writer.writeByte(record.progress.value);
    try writer.writeInt(u16, record.stats.level, .little);
    try writer.writeInt(u16, record.stats.exp, .little);
    try writer.writeInt(i32, record.stats.health, .little);
    try writer.writeInt(i32, record.stats.maxHealth, .little);
    try writer.writeInt(u16, record.stats.attack, .little);
    try writer.writeInt(u16, record.stats.defend, .little);
    try writer.writeInt(u16, record.stats.agility, .little);
    try writer.writeInt(u32, record.inventory.money, .little);
    for (record.inventory.items) |item| {
        try writer.writeByte(if (item) |key| @intCast(@backingInt(key)) else 255);
    }
    for (0..zon.Chest.list.len) |id| {
        try writer.writeByte(@intFromBool(record.openedChests.isSet(id)));
    }
    for (std.enums.values(zon.Actor.Key)) |key| {
        try writer.writeByte(@intFromBool(record.deadActors.contains(key)));
    }
}

fn readRecord(bytes: []const u8) !Record {
    var reader = std.Io.Reader.fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "SJY1")) return error.InvalidSave;
    var record: Record = .{ .location = undefined };
    record.location.map = std.enums.fromInt(zon.Map.Key, try reader.takeByte()) orelse
        return error.InvalidSave;
    record.location.position.x = @bitCast(try reader.takeInt(u32, .little));
    record.location.position.y = @bitCast(try reader.takeInt(u32, .little));
    record.location.facing = std.enums.fromInt(Facing, try reader.takeByte()) orelse
        return error.InvalidSave;
    record.progress.value = try reader.takeByte();
    record.stats.level = try reader.takeInt(u16, .little);
    record.stats.exp = try reader.takeInt(u16, .little);
    record.stats.health = try reader.takeInt(i32, .little);
    record.stats.maxHealth = try reader.takeInt(i32, .little);
    record.stats.attack = try reader.takeInt(u16, .little);
    record.stats.defend = try reader.takeInt(u16, .little);
    record.stats.agility = try reader.takeInt(u16, .little);
    record.inventory.money = try reader.takeInt(u32, .little);
    for (&record.inventory.items) |*item| {
        const value = try reader.takeByte();
        item.* = if (value == 255)
            null
        else
            std.enums.fromInt(zon.Item.Key, value) orelse return error.InvalidSave;
    }
    for (0..zon.Chest.list.len) |id| {
        if (try reader.takeByte() != 0) record.openedChests.set(id);
    }
    for (std.enums.values(zon.Actor.Key)) |key| {
        if (try reader.takeByte() != 0) record.deadActors.insert(key);
    }
    return record;
}
