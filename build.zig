const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const single_threaded = b.option(bool, "single-threaded", "Build artifacts that run in single threaded mode");

    const upstream = b.dependency("libpng", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = single_threaded,
    });
    lib_mod.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = &[_][]const u8{
            "png.c",
            "pngerror.c",
            "pngget.c",
            "pngmem.c",
            "pngpread.c",
            "pngread.c",
            "pngrio.c",
            "pngrtran.c",
            "pngrutil.c",
            "pngset.c",
            "pngtrans.c",
            "pngwio.c",
            "pngwrite.c",
            "pngwtran.c",
            "pngwutil.c",
            "mips/mips_init.c",
            "mips/filter_msa_intrinsics.c",
            "mips/filter_mmi_inline_assembly.c",
            "intel/intel_init.c",
            "intel/filter_sse2_intrinsics.c",
            "powerpc/powerpc_init.c",
            "powerpc/filter_vsx_intrinsics.c",
        },
        .flags = &.{
            //TODO
        },
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "png16",
        .root_module = lib_mod,
    });
    lib.installHeadersDirectory(upstream.path(""), "", .{
        .include_extensions = &.{
            "pngconf.h",
            "png.h",
        },
    });
    b.installArtifact(lib);

    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "png16",
        .root_module = lib_mod,
    });
    // Install with no version extension
    b.installArtifact(dynamic_lib);
    // Install with version extension
    const output_name = b.fmt("libpng16{s}.{s}", .{
        dynamic_lib.root_module.resolved_target.?.result.dynamicLibSuffix(),
        "1.6.48",
    });
    const install_step = b.addInstallArtifact(dynamic_lib, .{
        .dest_dir = .{
            .override = .lib,
        },
        .dest_sub_path = output_name,
    });
    b.getInstallStep().dependOn(&install_step.step);

    addExecutable(b, target, optimize, upstream, lib, "pngcp", "contrib/tools/pngcp.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngcpsh", "contrib/tools/pngcp.c");
    addExecutable(b, target, optimize, upstream, lib, "pngfix", "contrib/tools/pngfix.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngfixsh", "contrib/tools/pngfix.c");
    addExecutable(b, target, optimize, upstream, lib, "pngimage", "contrib/libtests/pngimage.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngimagesh", "contrib/libtests/pngimage.c");
    addExecutable(b, target, optimize, upstream, lib, "pngtest", "pngtest.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngtestsh", "pngtest.c");
    addExecutable(b, target, optimize, upstream, lib, "pngunknown", "contrib/libtests/pngunknown.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngunknownsh", "contrib/libtests/pngunknown.c");
    addExecutable(b, target, optimize, upstream, lib, "timepng", "contrib/libtests/timepng.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "timepngsh", "contrib/libtests/timepng.c");
    addExecutable(b, target, optimize, upstream, lib, "pngstest", "contrib/libtests/pngstest.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngstestsh", "contrib/libtests/pngstest.c");
    addExecutable(b, target, optimize, upstream, lib, "pngvalid", "contrib/libtests/pngvalid.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, "pngvalidsh", "contrib/libtests/pngvalid.c");
}

fn addExecutable(b: *std.Build, target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode, libpng: *std.Build.Dependency, lib: *std.Build.Step.Compile,
    name: []const u8, filename: []const u8) void {

    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = true,
    });
    exe_mod.addCSourceFiles(.{
        .root = libpng.path("."),
        .files = &[_][]const u8{
            filename,
        },
    });
    exe_mod.linkLibrary(lib);
    exe_mod.linkLibrary(zlib_dep.artifact("z"));
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
}
