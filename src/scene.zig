const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;

const title = @import("ui/title.zig");
const battle = @import("battle/battle.zig");
const component = @import("component.zig");
const touch = zhu.extend.touch;
const debug = zhu.extend.debug;
const map = @import("map.zig");
const storage = @import("storage.zig");
const system = @import("system/system.zig");
const ui = @import("ui/ui.zig");
const zon = @import("zon.zig");

const Scene = enum { title, world, battle };
const From = union(enum) { fromStart, fromBattle, fromLoad: u8 };

var current: Scene = .title;
var pending: Scene = .title;
var from: From = undefined;
var fade: Fade = .{};

// 是否显示键盘操作说明，在初始化时根据输入环境决定。
var isHelp: bool = undefined;
var world: ecs.World = undefined;
// 场景负责保存应用分配器，并向需要分配内存的模块传递。
var allocator: zhu.Allocator = undefined;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;
    isHelp = !zhu.key.mayNotHave;
    world = ecs.World.init(allocator_.raw);
    // 调试功能键作为游戏默认配置，页面补丁可临时覆盖。
    const extra = touch.pad.defaults.getPtr(.extra);
    extra.key = .X;
    extra.label = "调试";
    touch.init(.pad);
    title.init();
    ui.init();
    map.init(allocator_);
    battle.init(allocator_);

    title.enter();
    fade.startIn();
}

fn changeScene(next: Scene) void {
    pending = next;
    fade.startOut(doChangeScene);
}

fn changeWorld(next: From) void {
    from = next;
    changeScene(.world);
}

fn doChangeMap() void {
    map.enter(&world, .portal);
}

fn doChangeScene() void {
    var location: ?storage.Location = null;
    if (pending == .world and from == .fromLoad) {
        const load = from.fromLoad;
        location = storage.load(&world, load) orelse return;
    }

    switch (current) {
        .title => title.exit(),
        .world => {},
        .battle => battle.exit(&world),
    }
    current = pending;
    switch (current) {
        .title => title.enter(),
        .world => enterWorld(location),
        .battle => battle.enter(&world),
    }
}

fn enterWorld(location: ?storage.Location) void {
    ui.reset();
    switch (from) {
        .fromStart => {
            storage.reset(&world);
            map.enter(&world, .start);
            world.addResource(component.dialog.Dialog{
                .lines = zon.dialogues[2].lines,
            });
        },
        .fromBattle => {},
        .fromLoad => map.enter(&world, .{
            .location = location.?,
        }),
    }
    zhu.audio.playMusic("audio/back.mid");
}

pub fn update(delta: f32) void {
    if (zon.input.released(.help)) isHelp = !isHelp;
    if (zon.input.released(.debug)) debug.enabled = !debug.enabled;

    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (fade.update(delta)) return;
    switch (current) {
        .title => if (title.update(delta)) |req| switch (req) {
            .fadeOut => |done| fade.startOut(done),
            .start => changeWorld(.fromStart),
            .load => |slot| changeWorld(.{ .fromLoad = slot }),
        },
        .world => updateWorld(delta),
        .battle => if (battle.update(&world, delta)) |request| {
            switch (request) {
                .world => changeWorld(.fromBattle),
                .title => changeScene(.title),
            }
        },
    }
}

fn updateWorld(delta: f32) void {
    // 上一帧的场景请求在本帧开始处理，切图优先于战斗。
    var sceneRequest: ?component.event.Request = null;
    for (world.getEvent(component.event.Request)) |request| {
        sceneRequest = request;
        if (request == .map) break;
    }
    world.clearEvent(component.event.Request);

    if (sceneRequest) |request| switch (request) {
        .map => return fade.startOut(doChangeMap),
        .battle => return changeScene(.battle),
    };

    if (ui.update(&world, delta)) |request| {
        switch (request) {
            .block => {},
            .battle => changeScene(.battle),
            .load => |slot| changeWorld(.{ .fromLoad = slot }),
            .save => |slot| storage.save(&world, slot),
            .title => changeScene(.title),
        }
        return;
    }

    system.update(&world, delta);
}

pub fn draw() void {
    switch (current) {
        .title => title.draw(),
        .world => {
            map.draw();
            system.render.draw(&world);
            ui.draw(&world);
        },
        .battle => battle.draw(&world),
    }

    fade.draw();
    // 摇杆和功能按钮绘制在遮罩上方，不参与场景淡入淡出。
    touch.draw();

    camera.push(.window);
    defer camera.pop();
    if (isHelp) drawHelpInfo() else if (debug.enabled) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(text, .xy(10, 5), .{ .color = .green });
}

fn drawDebugInfo() void {
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    debug.draw(&.{});
}

pub fn deinit() void {
    world.deinit();
    map.deinit(allocator);
    zhu.audio.setMusicState(.stopped);
    battle.deinit(allocator);
}

// 管理场景切换时的淡入淡出状态。
const Fade = struct {
    timer: ?zhu.Timer = null,
    isIn: bool = false,
    done: ?*const fn () void = null,

    fn startIn(self: *Fade) void {
        self.timer = .init(1);
        self.isIn = true;
        self.done = null;
    }

    fn startOut(self: *Fade, done: ?*const fn () void) void {
        // 淡出期间界面停止更新，先释放它留下的虚拟按键。
        touch.reset();
        self.timer = .init(1);
        self.isIn = false;
        self.done = done;
    }

    // 推进淡入淡出，并返回本帧是否由它占用。
    fn update(self: *Fade, delta: f32) bool {
        const timer = if (self.timer) |*v| v else return false;
        if (timer.updateRunning(delta)) return true;

        if (self.isIn) {
            self.timer = null;
        } else {
            if (self.done) |done| done();
            self.startIn();
        }
        return true;
    }

    fn draw(self: *Fade) void {
        const timer = if (self.timer) |*v| v else return;
        camera.push(.window);
        defer camera.pop();

        const percent = timer.progress();
        const alpha = if (self.isIn) 1 - percent else percent;
        zhu.batch.drawRect(.init(.zero, camera.size), .{
            .color = .rgba(0, 0, 0, alpha),
        });
    }
};
