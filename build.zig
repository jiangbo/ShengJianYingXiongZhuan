const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
        .font = .system,
        .midi = true,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });

    // 生成图片图集，尺寸上限容纳地图素材。
    zhuBuild.atlas.addStep(b, zhuyu, .{ .maxSize = 2048 });

    // 转换原始音频并统一采样率，其他格式原样拷贝。
    try zhuBuild.audio.addStep(b, zhuyu, .{ .rate = 11025 });

    // 应用模块同时用于构建产物和测试。
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // 仅 Debug 保留调试符号。
        .strip = optimize != .debug,
        .imports = &.{
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });

    // 在资源安装前复制图片。
    const copy = b.addUpdateSourceFiles();
    copy.addCopyFileToSource(b.path("raw-assets/icon.png"), "assets/icon.png");
    copy.addCopyFileToSource(b.path("raw-assets/title.png"), "assets/title.png");

    const tests = b.addTest(.{ .name = "tests", .root_module = mod });
    zhuBuild.setLibC(zhuyu, tests);
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&runTests.step);

    zhuBuild.installEmsdk(b, zhuyu);
    if (target.result.os.tag == .emscripten) {
        const web = try zhuBuild.buildWeb(b, zhuyu, .{
            .name = "sjyxz",
            .root_module = mod,
            .shell = b.path("index.html"),
        });
        b.getInstallStep().dependOn(&web.step);
        const assets = b.addInstallDirectory(.{
            .source_dir = b.path("assets"),
            .install_dir = .prefix,
            .install_subdir = "web/assets",
        });
        assets.step.dependOn(&copy.step);
        b.getInstallStep().dependOn(&assets.step);
        return;
    }

    const exe = b.addExecutable(.{ .name = "sjyxz", .root_module = mod });
    zhuBuild.setLibC(zhuyu, exe);
    // Windows 调试时显示控制台日志，发布时不创建控制台窗口。
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.subsystem = if (mod.optimize.? == .debug) .console else .windows;
        if (exe.rootModuleTarget().abi == .msvc) {
            // 窗口模式也由微软 CRT 初始化后调用 Zig 的 main。
            exe.entry = .{ .symbol_name = "mainCRTStartup" };
        }
        // 在构建缓存中生成资源脚本，将米白底角色图标嵌入 EXE。
        const files = b.addWriteFiles();
        exe.root_module.addWin32ResourceFile(.{
            .file = files.add("icon.rc", "1 ICON \"icon.ico\"\n"),
            .include_paths = &.{b.path("raw-assets")},
        });
    }

    // 图片复制完成后，再将资源目录安装到可执行文件旁边。
    const assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    assets.step.dependOn(&copy.step);
    b.getInstallStep().dependOn(&assets.step);

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}
