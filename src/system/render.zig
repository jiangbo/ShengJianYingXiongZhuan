const ecs = @import("ecs");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Animation = component.Animation;
const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Position = component.Position;
const Sprite = component.Sprite;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{ Facing, Animation });
    while (query.next()) |entity| {
        const facing = query.get(entity, Facing);
        const animation = query.getPtr(entity, Animation);
        const sourceIndex: u8 = @backingInt(facing);

        var changed = animation.sourceIndex != sourceIndex;
        if (changed) animation.play(sourceIndex);
        if (world.has(entity, WantMove)) {
            if (animation.update(delta) != null) changed = true;
        }
        if (!changed) continue;
        world.getPtr(entity, Sprite).?.image = animation.subImage();
    }

    const position = world.getIdentity(Player, Position).?;
    zhu.camera.directFollow(position);
    zhu.camera.roundMainPosition();
}

pub fn draw(world: *ecs.World) void {
    world.sort(Position, lessY);

    var query = world.queryBy(Position, .{Sprite}, .{});
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const sprite = query.get(entity, Sprite);
        const drawPosition = zhu.camera.round(position, null);
        zhu.batch.drawImage(sprite.image, drawPosition, .{
            .anchor = sprite.anchor,
        });
    }
}

fn lessY(lhs: Position, rhs: Position) bool {
    return lhs.y < rhs.y;
}
