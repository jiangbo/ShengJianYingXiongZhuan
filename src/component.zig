const zhu = @import("zhu");

const zon = @import("zon.zig");

pub const Animation = zhu.Animation;

// 玩家进入后切换地图的区域。
pub const Portal = struct {
    key: zon.Portal.Key,
    area: zhu.Rect,
};

// 实体当前绘制的图片和对齐位置。
pub const Sprite = struct {
    image: zhu.Image,
    anchor: zhu.Vector2 = .zero,
};

// 实体在地图中的逻辑位置。
pub const Position = zhu.Vector2;

// 相对实体逻辑位置的碰撞区域。
pub const Collider = zhu.Rect;

// 地图中的宝箱和稳定标识。
pub const Chest = struct {
    id: u16,
};

// 宝箱关闭和开启状态使用的图片。
pub const ChestImages = struct {
    closed: zhu.Image,
    opened: zhu.Image,
};

pub const actor = struct {
    // 地图人物的稳定标识。
    pub const Key = zon.Actor.Key;

    // 实体当前面对的方向。
    pub const Facing = zon.Facing;

    pub fn oppositeFacing(facing: Facing) Facing {
        return switch (facing) {
            .down => .up,
            .left => .right,
            .up => .down,
            .right => .left,
        };
    }

    pub const Player = struct {};
    // 敌人相对实体逻辑位置的战斗触发区域。
    pub const Enemy = struct {
        value: zhu.Rect,
        // 逃跑后暂时停止触发战斗。
        wait: f32 = 0,
    };
    pub const Wander = struct { value: zhu.Timer };
};

// 可交互实体；Identity 指向当前交互对象。
pub const Interact = struct {};
pub const dialog = struct {
    // 由对话系统处理的可交互实体。
    pub const Talk = []const zon.dialog.Line;

    pub const Value = union(enum) { number: u32, text: []const u8 };

    // 当前活动的对话，作为 World 资源保存。
    pub const Dialog = struct {
        lines: Talk,
        // 当前显示行。
        line: usize = 0,
        // UI 当前绘制的文本。
        text: ?[]const u8 = null,
        value: ?Value = null,
    };
};

// 实体希望移动的单位方向。
pub const WantMove = struct { value: zhu.Vector2 };
pub const Speed = struct { value: f32 };

// 系统间通信的一次性消息。
pub const event = struct {
    // 已经越过的剧情进度。
    pub const Story = struct {
        progress: u8,
    };

    // 普通地图系统发给场景的切换请求。
    pub const Request = enum { map, battle };

    // 系统请求 UI 显示的临时提示。
    pub const Tip = struct {
        text: []const u8,
    };
};
