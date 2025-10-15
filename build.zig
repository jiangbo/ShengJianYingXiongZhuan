const std = @import("std");
const sk = @import("sokol");

const Options = struct {
    mod: *std.Build.Module,
    sokol: *std.Build.Dependency,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const exeModule = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = sokol.module("sokol") },
        },
    });

    const options = Options{ .mod = exeModule, .sokol = sokol };
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, options);
    } else {
        try buildNative(b, options);
    }
}

fn buildNative(b: *std.Build, options: Options) !void {
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;
    if (optimize != .Debug) exe.subsystem = .Windows;

    const zhuModule = b.createModule(.{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zhu", zhuModule);

    if (optimize != .Debug) exe.subsystem = .Windows;

    b.installArtifact(exe);

    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    zhuModule.addImport("sokol", sokol.module("sokol"));

    const writeFiles = b.addWriteFiles();
    exe.step.dependOn(&writeFiles.step);

    const stb = b.dependency("stb", .{ .target = target, .optimize = optimize });
    zhuModule.addIncludePath(stb.path("."));
    const stbImagePath = writeFiles.add("stb_image.c", stbImageSource);
    zhuModule.addCSourceFile(.{ .file = stbImagePath, .flags = &.{"-O2"} });

    const stbAudioPath = writeFiles.add("stb_audio.c", stbAudioSource);
    zhuModule.addCSourceFile(.{ .file = stbAudioPath, .flags = &.{"-O2"} });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}

fn buildWeb(b: *std.Build, options: Options) !void {
    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;

    const exe = b.addLibrary(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const zhuModule = b.createModule(.{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zhu", zhuModule);

    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    zhuModule.addImport("sokol", sokol.module("sokol"));

    const emsdk = options.sokol.builder.dependency("emsdk", .{});
    const include = emsdk.path(b.pathJoin(&.{ "upstream", "emscripten", "cache", "sysroot", "include" }));
    zhuModule.addSystemIncludePath(include);

    const writeFiles = b.addWriteFiles();
    exe.step.dependOn(&writeFiles.step);

    const stbAudioPath = writeFiles.add("stb_audio.c", stbAudioSource);
    zhuModule.addCSourceFile(.{ .file = stbAudioPath, .flags = &.{ "-O2", "-fno-sanitize=undefined" } });

    const emPath = writeFiles.add("em.c", emSource);
    zhuModule.addCSourceFile(.{ .file = emPath, .flags = &.{ "-O2", "-fno-sanitize=undefined" } });

    const stb = b.dependency("stb", .{ .target = target, .optimize = optimize });
    zhuModule.addIncludePath(stb.path("."));
    const stbImagePath = writeFiles.add("stb_image.c", stbImageSource);
    zhuModule.addCSourceFile(.{ .file = stbImagePath, .flags = &.{ "-O2", "-fno-sanitize=undefined" } });

    const link_step = try sk.emLinkStep(b, .{
        .lib_main = exe,
        .target = target,
        .optimize = optimize,
        .use_webgl2 = true,
        .emsdk = emsdk,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = b.path("index.html"),
    });

    // attach Emscripten linker output to default install step
    b.getInstallStep().dependOn(&link_step.step);
}

const stbImageSource =
    \\
    \\#define STB_IMAGE_IMPLEMENTATION
    \\#define STBI_ONLY_PNG
    \\#define STBI_NO_STDIO
    \\#include "stb_image.h"
    \\
;

const stbAudioSource =
    \\
    \\#define STB_VORBIS_NO_PUSHDATA_API
    \\#define STB_VORBIS_NO_INTEGER_CONVERSION
    \\#define STB_VORBIS_NO_STDIO
    \\
    \\#include "stb_vorbis.c"
    \\
;

const emSource =
    \\#if defined(__EMSCRIPTEN__)
    \\
    \\#include <emscripten.h>
    \\
    \\EM_JS(void, em_js_file_save, (const char *c_path, const char *c_data, int len), {
    \\    const path = UTF8ToString(c_path);
    \\    console.log("save file: ",path);
    \\    const bytes = HEAPU8.subarray(c_data, c_data + len);
    \\    console.log("save file bytes len: ",len);
    \\    const base64 = btoa(String.fromCharCode(...bytes));
    \\    window.localStorage.setItem(path, base64);
    \\});
    \\
    \\EM_JS(int, em_js_file_load, (const char *c_path, char *out_buf, int len), {
    \\    const path = UTF8ToString(c_path);
    \\    console.log("load file: ",path);
    \\    const base64 = window.localStorage.getItem(path);
    \\    if (!base64) return 0;
    \\
    \\    const binary = atob(base64);
    \\    if (binary.length > len) return 0;
    \\    for (let i = 0; i < binary.length; i++) {
    \\        HEAPU8[out_buf + i] = binary.charCodeAt(i);
    \\    }
    \\    return binary.length;
    \\});
    \\
    \\int my_add(int a, int b)
    \\{
    \\    return a + b;
    \\}
    \\
    \\#endif // defined(__EMSCRIPTEN__)
    \\
;
