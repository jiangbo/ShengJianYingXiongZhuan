const std = @import("std");

const sk = @import("sokol");
const math = @import("math.zig");

const gfx = sk.gfx;

pub const Texture = struct {
    view: gfx.View,
    area: math.Rect = .{},

    pub fn width(self: *const Texture) f32 {
        return self.size().x;
    }

    pub fn height(self: *const Texture) f32 {
        return self.size().y;
    }

    pub fn size(self: *const Texture) math.Vector2 {
        return self.area.size;
    }

    pub fn subTexture(self: *const Texture, area: math.Rect) Texture {
        return .{ .view = self.view, .area = area.move(self.area.min) };
    }

    pub fn mapTexture(self: *const Texture, area: math.Rect) Texture {
        return Texture{ .view = self.view, .area = area };
    }

    pub fn deinit(self: *Texture) void {
        sk.gfx.destroyImage(self.image);
    }
};

pub fn queryTextureSize(texture: Texture) math.Vector {
    const image = gfx.queryViewImage(texture.view);
    return math.Vector{
        .x = @floatFromInt(gfx.queryImageWidth(image)),
        .y = @floatFromInt(gfx.queryImageHeight(image)),
    };
}

pub const RenderPipeline = gfx.Pipeline;
pub const asRange = gfx.asRange;
pub const queryBackend = gfx.queryBackend;
pub const Buffer = gfx.Buffer;
pub const Color = gfx.Color;
pub var nearestSampler: gfx.Sampler = undefined;
pub var linearSampler: gfx.Sampler = undefined;

pub fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    nearestSampler = gfx.makeSampler(.{});
    linearSampler = gfx.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });
}

pub fn begin(color: gfx.Color) void {
    var action = gfx.PassAction{};
    action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
    gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
}

pub fn setPipeline(pipeline: RenderPipeline) void {
    gfx.applyPipeline(pipeline);
}

pub fn setUniform(index: u32, uniform: anytype) void {
    gfx.applyUniforms(index, gfx.asRange(&uniform));
}

pub fn setBindGroup(group: BindGroup) void {
    gfx.applyBindings(group.value);
}

pub fn drawInstanced(number: usize) void {
    gfx.draw(0, 4, @intCast(number));
}

pub fn end() void {
    gfx.endPass();
    gfx.commit();
}

pub fn scissor(area: math.Rect) void {
    const x, const y = .{ area.min.x, area.min.y };
    gfx.applyScissorRectf(x, y, area.size.x, area.size.y, true);
}

pub fn createTexture(size: math.Vector, data: []const u8) Texture {
    return Texture{
        .view = sk.gfx.makeView(.{ .texture = .{
            .image = gfx.makeImage(.{
                .data = init: {
                    var imageData = gfx.ImageData{};
                    imageData.mip_levels[0] = gfx.asRange(data);
                    break :init imageData;
                },
                .width = @intFromFloat(size.x),
                .height = @intFromFloat(size.y),
                .pixel_format = .RGBA8,
            }),
        } }),
        .area = .init(.zero, size),
    };
}

pub fn createBuffer(desc: gfx.BufferDesc) Buffer {
    return gfx.makeBuffer(desc);
}

pub const QuadVertex = extern struct {
    position: math.Vector3, // 顶点坐标
    size: math.Vector2, // 大小
    texture: math.Vector4, // 纹理坐标
    color: math.Vector4 = .one, // 顶点颜色
};

pub fn createQuadPipeline(shaderDesc: gfx.ShaderDesc) RenderPipeline {
    var vertexLayout = gfx.VertexLayoutState{};
    vertexLayout.attrs[0].format = .FLOAT3;
    vertexLayout.attrs[1].format = .FLOAT2;
    vertexLayout.attrs[2].format = .FLOAT4;
    vertexLayout.attrs[3].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    return gfx.makePipeline(.{
        .shader = gfx.makeShader(shaderDesc),
        .layout = vertexLayout,
        .primitive_type = .TRIANGLE_STRIP,
        .colors = init: {
            var c: [8]gfx.ColorTargetState = @splat(.{});
            c[0] = .{ .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            } };
            break :init c;
        },
    });
}

pub fn appendBuffer(buffer: Buffer, data: anytype) void {
    _ = gfx.appendBuffer(buffer, gfx.asRange(data));
}

pub fn frameStats(enable: bool) void {
    if (enable) gfx.enableFrameStats() else gfx.disableFrameStats();
}

pub fn queryFrameStats() gfx.FrameStats {
    return gfx.queryFrameStats();
}

pub const BindGroup = struct {
    value: gfx.Bindings = .{},

    pub fn setVertexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.vertex_buffers[0] = buffer;
    }

    pub fn setVertexOffset(self: *BindGroup, offset: usize) void {
        self.value.vertex_buffer_offsets[0] = @intCast(offset);
    }

    pub fn setTexture(self: *BindGroup, texture: Texture) void {
        self.value.views[0] = texture.view;
    }

    pub fn setSampler(self: *BindGroup, sampler: sk.gfx.Sampler) void {
        self.value.samplers[0] = sampler;
    }
};
