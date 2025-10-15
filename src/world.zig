const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const talk = @import("talk.zig");
const about = @import("about.zig");
const item = @import("item.zig");
const npc = @import("npc.zig");
const context = @import("context.zig");

const State = union(enum) {
    map: MapState,
    menu: MenuState,
    status,
    item,
    load: LoadState,
    save: SaveState,
    about: AboutState,
    talk: TalkState,
    shop,
    sale: SaleState,

    pub fn update(self: State, delta: f32) void {
        switch (self) {
            .status => {},
            .item => _ = player.openItem(),
            .shop => shop.update(),
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    pub fn draw(self: State) void {
        switch (self) {
            .map => {},
            .status => player.drawStatus(),
            .item => player.drawOpenItem(),
            .about => about.draw(),
            .talk => talk.draw(),
            .sale => player.drawSellItem(),
            .shop => shop.draw(),
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};
var texture: gfx.Texture = undefined;
var state: State = .map;
pub var back: enum { none, talk, battle, menu } = .none;
pub var tip: []const u8 = &.{};
var header: []const u8 = &.{};
var headerIndex: usize = 0;
var headerTimer: window.Timer = .init(0.08);
var headerColor: gfx.Color = .white;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/mainmenu1.png", .init(150, 200));

    item.init();
    talk.init();
    about.init();
    map.init();
    player.init();
    npc.init();
}

pub fn deinit() void {
    window.stopMusic();
}

pub fn enter() void {
    const playerPosition = map.enter();
    switch (back) {
        .none => {
            player.enter(playerPosition);
            context.battleNpcIndex = 0;
            context.oldMapIndex = 0;
            talk.active = 4;
            state = .talk;
        },
        .talk => talk.activeNext(),
        .battle => state = .map,
        .menu => state = .menu,
    }
    if (loadPlayerPosition) |pos| player.position = pos;
    loadPlayerPosition = null;
    player.cameraLookAt();
    npc.enter();
    menu.active = 6;
    window.playMusic("assets/voc/back.ogg");
}

pub fn changeMap() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
}

pub fn exit() void {}

pub fn update(delta: f32) void {
    if (tip.len != 0) {
        if (window.isAnyRelease()) tip = &.{} else return;
    }

    if (header.len != 0) {
        if (header.len == headerIndex) {
            // 已经显示结束了，等待按键
            if (window.isAnyRelease()) {
                if (player.progress > 20)
                    // 如果打败了大魔王，跳转到标题界面
                    scene.changeScene(.title)
                else {
                    header = &.{};
                    state = .map;
                }
            }
        } else if (headerTimer.isFinishedAfterUpdate(delta)) {
            // 没有显示结束，继续显示
            headerIndex = zhu.utf8NextIndex(header, headerIndex);
            headerTimer.reset();
        }
        return;
    }

    //  map: MapState,
    // menu: MenuState,
    // status,
    // item,
    // load: LoadState,
    // save: SaveState,
    // about: AboutState,
    // talk: TalkState,
    // shop,
    // sale: SaleState,

    if (state == .map or state == .status or state == .item or
        state == .about)
    {
        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            state = .menu;
            return;
        }
    }

    state.update(delta);
}

pub fn draw() void {
    map.draw();
    npc.draw();
    player.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    if (tip.len != 0) {
        camera.drawColorText(tip, .init(242, 442), .black);
        camera.drawColorText(tip, .init(240, 440), .yellow);
    }
    state.draw();
    if (header.len != 0) {
        camera.drawTextOptions(header[0..headerIndex], .{
            .position = .init(80, 100),
            .width = 520,
            .color = headerColor,
        });
    }
}

const MapState = struct {
    var warn: bool = false;

    fn update(delta: f32) void {
        npc.update(delta);
        player.update(delta);

        // 检测是否需要切换地图
        const area = math.Rect.init(player.position, player.SIZE);
        const object = map.getObject(map.positionIndex(area.center()));
        if (object > 4) {
            if (!warn) return changeMapIfNeed(object);
        } else warn = false;

        // 遇敌
        if (npc.battle(area, player.facing)) |npcIndex| {
            // 是否需要对话
            if (npc.zon[npcIndex].talks.len != 0) {
                talk.active = npc.zon[npcIndex].talks[0];
                state = .talk;
            } else {
                context.oldMapIndex = map.linkIndex;
                context.battleNpcIndex = npcIndex;
                back = .battle;
                scene.changeScene(.battle);
            }
            return;
        }

        // 交互检测
        if (!window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) return;
        // 开启宝箱
        const talkObject = map.talk(player.position, player.facing);
        if (talkObject) |pickupIndex| openChest(pickupIndex);

        // 和 NPC 对话
        if (npc.talk(player.talkCollider(), player.facing)) |talkId| {
            talk.active = talkId;
            state = .talk;
        }
    }

    fn changeMapIfNeed(object: u8) void {
        const link = map.links[object];
        if (player.progress > link.progress) {
            std.log.info("change map link index: {d}", .{object});
            map.linkIndex = object;
            scene.changeMap();
            return;
        }

        if (player.progress == 1) {
            warn = true;
            talk.active = 17;
            state = .talk;
        }

        if (player.progress == 4) {
            player.progress += 1;
            talk.active = 143;
            state = .talk;
        }

        if (player.progress == 10) {
            warn = true;
            talk.active = 172;
            state = .talk;
        }
    }

    fn openChest(pickIndex: u16) void {
        const object = item.pickupZon[pickIndex];

        if (object.itemIndex == 0 and object.count == 0) {
            const gold = math.randU8(10, 100);
            player.money += gold;
            talk.activeNumber(2, gold);
            state = .talk;
        } else {
            const added = player.addItem(object.itemIndex);
            if (!added) {
                tip = "你已经带满了！";
                return;
            }
            talk.activeText(3, item.zon[object.itemIndex].name);
            state = .talk;
        }
        map.openChest(pickIndex);
    }
};

const MenuState = struct {
    fn update(_: f32) void {
        const menuEvent = menu.update();
        if (menuEvent) |event| switch (event) {
            0 => state = .status,
            1 => state = .item,
            2 => {
                menu.active = 5;
                state = .load;
            },
            3 => {
                menu.active = 5;
                state = .save;
            },
            4 => {
                about.resetRoll();
                state = .about;
            },
            5 => window.exit(),
            6 => state = .map,
            else => unreachable,
        };

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            state = .map;
        }
    }

    fn draw() void {
        camera.draw(texture, .init(0, 280));
        menu.draw();
    }
};

var loadPlayerPosition: ?math.Vector2 = null;
const LoadState = struct {
    pub fn update(_: f32) void {
        const loadEvent = menu.update();
        if (loadEvent) |event| switch (event) {
            3...7 => |index| {
                back = .menu;
                scene.changeScene(.world);
                load(index) catch {
                    menu.active = 6;
                    state = .menu;
                };
            },
            8 => {
                menu.active = 6;
                state = .menu;
            },
            else => unreachable,
        };

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            menu.active = 6;
            state = .menu;
        }
    }

    pub fn draw() void {
        camera.draw(texture, .init(0, 280));
        menu.draw();
    }
};

const magic = [2]u8{ 0xB0, 0x0B };
pub fn load(index: u8) !void {
    var buffer: [100]u8 = undefined;
    var buf: [20]u8 = undefined;
    const path = zhu.formatZ(&buf, "save/{d}.save", .{index - 2});
    const slice = try window.readAll(path, &buffer);
    var stream = std.io.fixedBufferStream(slice);
    var reader = stream.reader();

    // 1. magic
    var magic_buf: [magic.len]u8 = undefined;
    try reader.readNoEof(&magic_buf);
    if (!std.mem.eql(u8, &magic_buf, &magic)) return error.InvalidMagic;

    // 2. 游戏版本号
    var version: [2]u8 = undefined;
    try reader.readNoEof(&version);

    // 3. 地图编号
    map.linkIndex = try reader.readByte();
    // 4. 玩家进度
    player.progress = try reader.readByte();
    // 5. 玩家坐标
    var pos = player.position;
    try reader.readNoEof(std.mem.asBytes(&pos));
    loadPlayerPosition = pos;
    // 6. 玩家经验
    try reader.readNoEof(std.mem.asBytes(&player.exp));
    // 7. 玩家等级
    try reader.readNoEof(std.mem.asBytes(&player.level));
    // 8. 玩家生命
    try reader.readNoEof(std.mem.asBytes(&player.health));
    // 9. 玩家最大生命
    try reader.readNoEof(std.mem.asBytes(&player.maxHealth));
    // 10. 玩家攻击力
    try reader.readNoEof(std.mem.asBytes(&player.attack));
    // 11. 玩家防御力
    try reader.readNoEof(std.mem.asBytes(&player.defend));
    // 12. 玩家速度
    try reader.readNoEof(std.mem.asBytes(&player.speed));
    // 13. 玩家金钱
    try reader.readNoEof(std.mem.asBytes(&player.money));
    // 14. 玩家物品
    try reader.readNoEof(std.mem.asBytes(&player.items));
    // 15. 宝箱状态
    try reader.readNoEof(std.mem.asBytes(&item.picked));
    // 16. NPC 状态
    try reader.readNoEof(std.mem.asBytes(&npc.dead));
    // 17. magic 结尾
    var magic_end: [magic.len]u8 = undefined;
    try reader.readNoEof(&magic_end);
    if (!std.mem.eql(u8, &magic_end, &magic)) return error.InvalidMagic;
}

const SaveState = struct {
    var buffer: [100]u8 = undefined;

    pub fn update(_: f32) void {
        const saveEvent = menu.update();
        if (saveEvent) |event| switch (event) {
            3...7 => |index| {
                back = .menu;
                scene.changeScene(.world);
                save(index) catch @panic("save failed");
            },
            8 => {
                menu.active = 6;
                state = .menu;
            },
            else => unreachable,
        };

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            menu.active = 6;
            state = .menu;
        }
    }

    fn save(index: u8) !void {
        var stream = std.io.fixedBufferStream(&buffer);
        var writer = stream.writer();
        try writer.writeAll(&magic);
        //  游戏版本号
        try writer.writeAll(&.{ 0x00, 0x00 });
        //  地图编号
        try writer.writeByte(map.linkIndex);
        //  玩家进度
        try writer.writeByte(player.progress);
        //  玩家坐标
        try writer.writeAll(std.mem.asBytes(&player.position));
        //  玩家经验
        try writer.writeAll(std.mem.asBytes(&player.exp));
        //  玩家等级
        try writer.writeAll(std.mem.asBytes(&player.level));
        //  玩家生命
        try writer.writeAll(std.mem.asBytes(&player.health));
        // 玩家最大生命
        try writer.writeAll(std.mem.asBytes(&player.maxHealth));
        //  玩家攻击力
        try writer.writeAll(std.mem.asBytes(&player.attack));
        //  玩家防御力
        try writer.writeAll(std.mem.asBytes(&player.defend));
        //  玩家速度
        try writer.writeAll(std.mem.asBytes(&player.speed));
        //  玩家金钱
        try writer.writeAll(std.mem.asBytes(&player.money));
        //  玩家物品
        try writer.writeAll(std.mem.asBytes(&player.items));
        //  宝箱状态
        try writer.writeAll(std.mem.asBytes(&item.picked));
        //  NPC 状态
        try writer.writeAll(std.mem.asBytes(&npc.dead));
        try writer.writeAll(&magic);

        var buf: [20]u8 = undefined;
        const path = zhu.formatZ(&buf, "save/{d}.save", .{index - 2});
        try window.saveAll(path, buffer[0..stream.pos]);
    }

    pub fn draw() void {
        camera.draw(texture, .init(0, 280));
        menu.draw();
    }
};

const TalkState = struct {
    fn update(_: f32) void {
        const talkEvent = talk.update();
        if (talkEvent) |event| switch (event) {
            0 => state = .map,
            4, 5 => |t| {
                state = .shop;
                shop = if (t == 4) &weaponShop else &potionShop;
            },
            6 => state = .sale,
            7, 8 => |e| {
                context.oldMapIndex = map.linkIndex;
                context.battleNpcIndex = talk.recentNpc();
                back = if (e == 7) .talk else .battle;
                scene.changeScene(.battle);
            },
            9 => {
                // 打败了巫批，对话完成
                header = "　　太好了！终于找到了失落已久的“圣剑”，就用它的威力把大魔王彻底杀死吧！　";
                headerColor = .white;
                headerTimer.reset();
            },
            10 => {
                // 打败了大魔王
                header =
                    \\　　祝贺你成功打爆试玩版！详细情况请看Readme.txt
                    \\敬请关注该游戏的最新动态：
                    \\　　http://goldpoint.126.com
                    \\　　　　　　　　　　　　　成都金点工作组制作
                    \\　　　　　　　　　　　　　[THE END]
                ;
                headerColor = .red;
                headerTimer.reset();
            },
            else => unreachable,
        };
    }
};

const AboutState = struct {
    fn update(delta: f32) void {
        if (about.roll) about.update(delta) //
        else if (window.isMouseRelease(.LEFT) or
            window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER }))
        {
            about.roll = true;
        }
    }
};

const SaleState = struct {
    var sell: bool = false;

    fn update(_: f32) void {
        const playerSell = player.sellItem();
        if (!sell) sell = playerSell;

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            talk.activeNext();
            if (sell) talk.activeNext();
            state = .talk;
            sell = false;
        }
    }
};

const Shop = struct {
    var bought: bool = false;
    items: [16]u8,
    current: u8 = 0,
    notBuyId: u16,
    buyId: u16,

    pub fn update(self: *Shop) void {
        self.current = item.update(self.items.len, self.current);

        if (window.isAnyKeyRelease(&.{ .LEFT_CONTROL, .F, .ENTER })) {
            const itemIndex = self.items[self.current];
            if (itemIndex != 0) {
                const playerBuy = buy(itemIndex);
                if (!bought) bought = playerBuy;
            }
        }

        if (window.isAnyKeyRelease(&.{ .Q, .E, .ESCAPE })) {
            talk.active = if (bought) self.buyId else self.notBuyId;
            state = .talk;
            bought = false;
        }
    }

    fn buy(itemIndex: u8) bool {
        const buyItem = item.zon[itemIndex];

        if (buyItem.money > player.money) {
            tip = "兄弟，你的钱不够！";
            return false;
        }

        const bagEnough = player.addItem(itemIndex);
        if (!bagEnough) {
            tip = "你已经带满了！";
            return false;
        }
        player.money -= buyItem.money;
        return true;
    }

    pub fn draw(self: *const Shop) void {
        item.draw(&self.items, self.current);
        var buffer: [20]u8 = undefined;
        // 金币，操作说明
        camera.drawText("（金=", item.position.addXY(10, 270));
        const moneyStr = zhu.format(&buffer, "{d}）", .{player.money});
        camera.drawText(moneyStr, item.position.addXY(60, 270));
        const text = "CTRL=购买　　ESC=退出";
        camera.drawText(text, item.position.addXY(118, 270));
    }
};
var weaponShop: Shop = .{
    .items = .{
        12, 12, 13, 13, 14, 14, 9, 9, //
        10, 10, 8,  8,  16, 16, 0, 0,
    },
    .notBuyId = 83,
    .buyId = 85,
};
var potionShop: Shop = .{
    .items = .{
        5,  5,  6,  6,  7, 7, 4, 4, //
        17, 17, 18, 18, 0, 0, 0, 0,
    },
    .notBuyId = 96,
    .buyId = 98,
};
var shop: *Shop = undefined;
