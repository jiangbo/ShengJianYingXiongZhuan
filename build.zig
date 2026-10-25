const std = @import("std");
const zhuBuild = @import("zhuyu");
const sk = zhuBuild.sokol;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const android = target.result.abi.isAndroid();

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
        // macOS 本机可省略，交叉编译时指定 MacOSX*.sdk 路径。
        .macos_sdk = b.option([]const u8, "macos-sdk", "macOS SDK directory"),
        .msdf = true,
        .midi = true,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });

    // 生成图片图集，尺寸上限容纳地图素材。
    zhuBuild.atlas.addStep(b, zhuyu, .{
        .input = "raw-assets/atlas",
        .maxSize = 2048,
    });

    // 从按用途分类的中文原文生成 MSDF，沿用当前生成字号。
    try zhuBuild.msdf.addStep(b, zhuyu, .{
        .font = "raw-assets/font/NotoSansCJKsc-Medium.otf",
        .input = "raw-assets/font/zh",
        .size = 28,
    });

    // 转换原始音频并统一采样率，其他格式原样拷贝。
    try zhuBuild.audio.addStep(b, zhuyu, .{
        .input = "raw-assets/audio",
        .rate = 11025,
    });

    // 应用模块同时用于构建产物和测试。
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // 所有平台仅 Debug 保留调试符号。
        .strip = optimize != .debug,
        .imports = &.{
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });

    // SDK 安装命令不依赖目标平台，与 Web 链接共用同一份依赖。
    const sokol = zhuyu.builder.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const emsdk = sokol.builder.dependency("emsdk", .{});
    const installEmsdk = sk.emSdkInstallStep(b, emsdk, .{});
    b.step("install-emsdk", "Install Emscripten SDK").dependOn(installEmsdk);

    if (android) {
        const lib = try zhuBuild.buildAndroid(b, zhuyu, .{
            .name = "demo",
            .root_module = mod,
            .sdk = b.option([]const u8, "sdk", "Android SDK directory"),
        });
        b.installArtifact(lib);
    } else if (target.result.os.tag == .emscripten) {
        try buildWeb(b, mod, emsdk);
    } else {
        buildNative(b, zhuyu, mod);
    }

    const tests = b.addTest(.{ .name = "tests", .root_module = mod });
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&runTests.step);
}

// 构建原生应用，安装产物并提供运行命令。
fn buildNative(
    b: *std.Build,
    zhuyu: *std.Build.Dependency,
    mod: *std.Build.Module,
) void {
    const exe = b.addExecutable(.{ .name = "demo", .root_module = mod });
    // Windows 所有构建模式都使用窗口子系统，不创建控制台窗口。
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.subsystem = .windows;
        // 在构建缓存中生成资源脚本，将米白底角色图标嵌入 EXE。
        const files = b.addWriteFiles();
        exe.root_module.addWin32ResourceFile(.{
            .file = files.add("icon.rc", "1 ICON \"icon.ico\"\n"),
            .include_paths = &.{b.path("raw-assets")},
        });
    }
    b.installArtifact(exe);

    // 原生资源安装到可执行文件旁边，供引擎按相对路径读取。
    b.installDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });

    // 由引擎注册资源打包命令，普通构建和运行使用原始程序。
    zhuBuild.addPackStep(b, zhuyu, .{ .exe = exe });

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}

// 构建 Web 静态库，再交给 Emscripten 链接和安装。
fn buildWeb(
    b: *std.Build,
    mod: *std.Build.Module,
    emsdk: *std.Build.Dependency,
) !void {
    const lib = b.addLibrary(.{ .name = "demo", .root_module = mod });
    const link = try sk.emLinkStep(b, .{
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
        .lib_main = lib,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        // TODO: Zig 修复 std.Io 未使用函数保留问题后，确认 Web 的 Debug 和
        // ReleaseSafe 在 false 下均可链接并正常运行，再关闭文件系统。
        // https://codeberg.org/ziglang/zig/issues/31421
        .use_filesystem = true,
        .shell_file_path = b.path("index.html"),
    });
    b.getInstallStep().dependOn(&link.step);

    // Web 资源随 HTML 一起安装。
    b.installDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .prefix,
        .install_subdir = "web/assets",
    });
}
