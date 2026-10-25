const zhu = @import("zhu");
const ecs = @import("ecs");
const touch = zhu.extend.touch;

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const player = @import("player.zig");
const enemy = @import("enemy.zig");
const shared = @import("shared.zig");

const Dialog = component.dialog.Dialog;
const Enemy = component.actor.Enemy;
const Key = component.actor.Key;
const Player = component.actor.Player;
const Position = component.Position;

pub const Request = enum { world, title };

// 当前阶段同时记录阶段标识和对应类型。
const Phase = union(shared.Phase) {
    menu: shared.Menu,
    playerAttack: player.Attack,
    enemyHurt: enemy.Hurt,
    wait: shared.Wait,
    enemyAttack: enemy.Attack,
    playerHurt: player.Hurt,
    playerDeath: player.Death,
    enemyDeath: enemy.Death,
    status: player.Status,
    item: player.Item,
    win: void,
    escape: void,
    title: void,

    // 只初始化实际需要进入处理的阶段。
    pub fn enter(self: Phase, world: *ecs.World) void {
        switch (self) {
            .win, .escape, .title => unreachable,
            .menu, .status => {},
            inline else => |value| @TypeOf(value).enter(world),
        }
    }

    // 更新当前阶段，并返回下一阶段标识。
    pub fn update(self: Phase, world: *ecs.World, delta: f32) ?shared.Phase {
        switch (self) {
            .win, .escape, .title => unreachable,
            inline else => |value| {
                return @TypeOf(value).update(world, delta);
            },
        }
    }

    // 只绘制实际拥有附加内容的阶段。
    pub fn draw(self: Phase, world: *ecs.World) void {
        switch (self) {
            .win, .escape, .title => unreachable,
            .menu => {},
            inline else => |value| @TypeOf(value).draw(world),
        }
    }
};

var texture: zhu.Image = undefined;
var mapImage: zhu.Image = undefined;
var mapImageGrid: zhu.extend.tiled.Grid = undefined;
var mapWindow: zon.TileWindow = undefined;
var phase: Phase = .menu;

// 初始化战斗场景长期使用的资源。
pub fn init(allocator: zhu.Allocator) void {
    texture = zhu.getImage("fightbar.png").?;
    mapImage = zhu.getImage("maps1-sheet.png").?;
    mapImageGrid = .{
        .width = @intFromFloat(@divExact(mapImage.size.x, 34)),
        .height = @intFromFloat(@divExact(mapImage.size.y, 34)),
        .cell = 34,
    };
    const data = zon.Map.get(.battle);
    mapWindow = .{
        .grid = data.grid,
        .padding = 0,
        .area = .init(.zero, data.grid.size()),
    };
    mapWindow.vertices.ensureTotalCapacity(
        allocator.raw,
        data.grid.count() * 2,
    ) catch zhu.oom();
    mapWindow.rebuildImage(
        mapImage,
        &.{ data.back, data.ground },
        mapImageGrid,
    );
    shared.bombAnimation = .initSource(zon.config.bomb);
}

// 释放战斗地图长期持有的顶点。
pub fn deinit(allocator: zhu.Allocator) void {
    mapWindow.vertices.deinit(allocator.raw);
}

// 读取选定的敌人并进入战斗场景。
pub fn enter(world: *ecs.World) void {
    const enemyKey = world.getIdentity(Enemy, Key).?;
    shared.enemyKey = enemyKey;
    shared.enemy = zon.Actor.get(enemyKey).*;
    shared.menu.reset();
    changePhase(world, .menu);
    zhu.camera.main.position = .zero;
}

// 离开战斗时恢复普通世界的玩家相机。
pub fn exit(world: *ecs.World) void {
    const position = world.getIdentity(Player, Position).?;
    zhu.camera.directFollow(position);
    zhu.camera.roundMainPosition();
}

// 切换阶段并初始化新阶段。
fn changePhase(world: *ecs.World, newPhase: shared.Phase) void {
    phase = switch (newPhase) {
        .win, .escape, .title => unreachable,
        inline else => |newTag| @unionInit( //
            Phase, @tagName(newTag), .{}),
    };
    phase.enter(world);
}

// 更新当前战斗阶段并返回场景请求。
pub fn update(world: *ecs.World, delta: f32) ?Request {
    const next = phase.update(world, delta);
    touch.update(); // 阶段内部只修改按钮配置，统一暂存下一帧的按键变化。
    const newPhase = next orelse return null;
    switch (newPhase) {
        .win => return finishWin(world),
        .escape => return finishEscape(world),
        .title => {
            world.removeIdentity(Enemy);
            return .title;
        },
        else => changePhase(world, newPhase),
    }
    return null;
}

// 记录死亡并删除普通地图中的敌人。
fn finishWin(world: *ecs.World) Request {
    const enemyEntity = world.getIdentityEntity(Enemy).?;
    const dead = world.getResourcePtr(storage.DeadActors).?;
    dead.insert(shared.enemyKey);
    world.removeIdentity(Enemy);
    world.destroyEntity(enemyEntity);
    return .world;
}

// 设置逃跑冷却并结束战斗前未完成的对话。
fn finishEscape(world: *ecs.World) Request {
    world.getIdentityPtr(Enemy, null).?.wait = 0.5;
    world.removeResource(Dialog);
    world.removeIdentity(Enemy);
    return .world;
}

// 绘制战斗场景、双方状态和当前阶段。
pub fn draw(world: *ecs.World) void {
    zhu.batch.drawVertices(mapWindow.vertices.items, mapImage);

    zhu.camera.push(.window);
    defer zhu.camera.pop();
    var buffer: [100]u8 = undefined;

    if (phase != .playerHurt and phase != .playerDeath) {
        const image = zon.Actor.image(.player, .right);
        zhu.batch.drawImage(image, .xy(130, 220), .{});
    }

    if (phase != .enemyHurt and phase != .enemyDeath) {
        const image = zon.Actor.image(shared.enemyKey, .left);
        zhu.batch.drawImage(image, .xy(465, 237), .{});
    }

    const position = zhu.Vector2.xy(96, 304);
    zhu.batch.drawImage(texture, position, .{});
    const playerPhoto = zon.Actor.image(.player, .down);
    zhu.batch.drawImage(playerPhoto, position.addXY(10, 10), .{});
    const enemyPhoto = zon.Actor.image(shared.enemyKey, .down);
    zhu.batch.drawImage(enemyPhoto, position.addXY(265, 26), .{});

    zhu.text.msdf.begin();

    const stats = world.getResourcePtr(storage.Stats).?;
    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        stats.health,
        stats.attack,
        stats.defend,
        stats.level,
    });
    zhu.text.draw(text, position.addXY(50, 5), .{ .color = .black });

    text = zhu.format(&buffer, format, .{
        shared.enemy.health,
        shared.enemy.attack,
        shared.enemy.defend,
        shared.enemy.level,
    });
    zhu.text.draw(text, position.addXY(305, 5), .{ .color = .black });
    zhu.text.msdf.end();

    shared.menu.draw();
    phase.draw(world);
}
