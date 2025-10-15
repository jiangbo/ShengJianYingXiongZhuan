const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/font.glsl.zig");
const window = @import("window.zig");

pub const Font = struct {
    atlas: struct {
        type: []const u8,
        distanceRange: u32,
        distanceRangeMiddle: u32,
        size: f32,
        width: u32,
        height: u32,
        yOrigin: []const u8,
    },
    metrics: struct {
        emSize: u32,
        lineHeight: f32,
        ascender: f32,
        descender: f32,
        underlineY: f32,
        underlineThickness: f32,
    },
    glyphs: []const Glyph,
    kerning: struct {},
};

const Glyph = struct {
    unicode: u32,
    advance: f32,
    planeBounds: Rect = .{},
    atlasBounds: Rect = .{},
};

const Rect = struct {
    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,

    fn toArea(self: Rect) math.Rect {
        const min = math.Vector2{ .x = self.left, .y = self.top };
        return .fromMax(min, .{ .x = self.right, .y = self.bottom });
    }
};

var font: Font = undefined;
var texture: gpu.Texture = undefined;
var invalidUnicode: u32 = 0x25A0;
var invalidIndex: usize = 0;

var pipeline: gpu.RenderPipeline = undefined;
var bindGroup: gpu.BindGroup = .{};
var buffer: gpu.Buffer = undefined;
var needDrawCount: u32 = 0;
pub var totalDrawCount: u32 = 0;

const initOptions = struct {
    font: Font,
    texture: gpu.Texture,
    vertexCount: usize = 500,
};

fn binarySearch(unicode: u32) ?usize {
    return std.sort.binarySearch(Glyph, font.glyphs, unicode, compare);
}

pub fn init(options: initOptions) void {
    font = options.font;
    invalidIndex = binarySearch(invalidUnicode).?;
    texture = options.texture;

    buffer = gpu.createBuffer(.{
        .size = @sizeOf(gpu.QuadVertex) * options.vertexCount,
        .usage = .{ .vertex_buffer = true, .stream_update = true },
    });

    const shaderDesc = shader.fontShaderDesc(gpu.queryBackend());
    pipeline = gpu.createQuadPipeline(shaderDesc);
}

fn searchGlyph(code: u32) *const Glyph {
    return &font.glyphs[binarySearch(code) orelse invalidIndex];
}

fn compare(a: u32, b: Glyph) std.math.Order {
    if (a < b.unicode) return .lt;
    if (a > b.unicode) return .gt;
    return .eq;
}

pub fn beginDraw() void {
    totalDrawCount = 0;
}

pub fn drawNumber(number: anytype, position: math.Vector) void {
    drawColorNumber(number, position, .one);
}

pub fn drawColorNumber(number: anytype, pos: math.Vector, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const text = std.fmt.bufPrint(textBuffer[0..], "{d}", .{number});
    const t = text catch unreachable;
    drawTextOptions(t, .{ .position = pos, .color = color });
}

pub fn drawText(text: []const u8, position: math.Vector) void {
    drawTextOptions(text, .{ .position = position });
}

pub const TextOptions = struct {
    size: f32 = 18,
    position: math.Vector,
    color: math.Vector4 = .one,
    width: f32 = std.math.floatMax(f32),
};

const Color = math.Vector4;
pub fn drawColorText(text: []const u8, pos: math.Vector, color: Color) void {
    drawTextOptions(text, .{ .position = pos, .color = color });
}

pub fn drawTextOptions(text: []const u8, options: TextOptions) void {
    const Utf8View = std.unicode.Utf8View;
    var iterator = Utf8View.initUnchecked(text).iterator();

    const offsetY = -font.metrics.ascender * options.size;
    var pos = options.position.addY(offsetY);

    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            const height = font.metrics.lineHeight * options.size;
            pos = .init(options.position.x, pos.y + height);
            continue;
        }
        if (pos.x > options.width) {
            const height = font.metrics.lineHeight * options.size;
            pos = .init(options.position.x, pos.y + height);
        }
        const char = searchGlyph(code);

        const target = char.planeBounds.toArea();
        gpu.appendBuffer(buffer, &.{gpu.QuadVertex{
            .position = pos.add(target.min.scale(options.size)).toVector3(0),
            .size = target.size.scale(options.size),
            .texture = char.atlasBounds.toArea().toVector4(),
            .color = options.color,
        }});
        needDrawCount += 1;
        totalDrawCount += 1;
        pos = pos.addX(char.advance * options.size);
    }
}

pub fn flush() void {
    if (needDrawCount == 0) return;

    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.logicSize.x, window.logicSize.y };
    const viewMatrix = [16]f32{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };
    const size = gpu.queryTextureSize(texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setSampler(gpu.linearSampler);
    bindGroup.setTexture(texture);
    bindGroup.setVertexBuffer(buffer);
    const vertexOffset = totalDrawCount - needDrawCount;
    bindGroup.setVertexOffset(vertexOffset * @sizeOf(gpu.QuadVertex));
    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(needDrawCount);
    needDrawCount = 0;
}
