const zhu = @import("zhu");
const ecs = @import("ecs");

const input = @import("../zon.zig").input;
const stats = @import("stats.zig");

var background: zhu.Image = undefined;
var playerPhoto: zhu.Image = undefined;

pub fn init() void {
    background = zhu.getImage("sbar.png").?;
    // 状态界面固定显示玩家向下动作的第一帧。
    playerPhoto = zhu.getImage("player.png").?.sub(
        .init(.zero, .xy(32, 48)),
    );
}

// 状态界面在普通场景和战斗场景中使用相同的关闭操作。
pub fn update() bool {
    return input.anyReleased(&.{ .confirm, .cancel, .menu }) or
        zhu.key.released(.MOUSE_LEFT);
}

pub fn draw(world: *ecs.World) void {
    const position = zhu.Vector2.xy(120, 90);
    zhu.batch.drawImage(background, position.addXY(-10, -10), .{});
    zhu.batch.drawImage(playerPhoto, position.addXY(10, 10), .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    stats.draw(world, position, 30);
}
