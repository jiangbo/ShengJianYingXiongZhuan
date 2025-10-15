@vs vs
layout(binding=0) uniform vs_params {
    mat4 viewMatrix;
    vec4 textureVec;
};

in vec4 vertex_position;
in vec2 vertex_size;
in vec4 vertex_texture;
in vec4 vertex_color;

const vec2 vertexArray[4] = {
    {0.0f, 0.0f},
    {1.0f, 0.0f},
    {0.0f, 1.0f},
    {1.0f, 1.0f},
};

out vec4 color;
out vec2 uv;

void main() {
    uint vertexIndex = uint(gl_VertexIndex) % 4;
    // 顶点
    vec2 position = vertexArray[vertexIndex] * vertex_size;
    vec4 depthPosition = vec4(position, 0, 0) + vertex_position;
    gl_Position = viewMatrix * depthPosition;

    // 纹理
    vec2 texcoord[4] = {
        {vertex_texture.x, vertex_texture.y},
        {vertex_texture.z, vertex_texture.y},
        {vertex_texture.x, vertex_texture.w},
        {vertex_texture.z, vertex_texture.w},
    };

    color = vertex_color;
    uv = texcoord[vertexIndex] * textureVec.xy;
}
@end

@fs fs

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec4 color;
in vec2 uv;
out vec4 frag_color;

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void main() {
    vec3 msd = texture(sampler2D(tex, smp), uv).rgb;
    float sd = median(msd.r, msd.g, msd.b) - 0.5;
    float opacity = clamp(2 * sd + 0.5, 0.0, 1.0);
    frag_color = vec4(color.rgb, opacity * color.w);
}
@end

@program font vs fs