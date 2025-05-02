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
    });

    const pnglibconf_h = generateConf(b, target);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "png16",
        .root_module = lib_mod,
    });
    lib.addConfigHeader(pnglibconf_h);
    lib.installHeadersDirectory(upstream.path(""), "", .{
        .include_extensions = &.{
            "pngconf.h",
            "png.h",
            "pnglibconf.h",
        },
    });
    b.installArtifact(lib);

    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "png16",
        .root_module = lib_mod,
    });
    dynamic_lib.addConfigHeader(pnglibconf_h);
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

    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngcp", "contrib/tools/pngcp.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngcpsh", "contrib/tools/pngcp.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngfix", "contrib/tools/pngfix.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngfixsh", "contrib/tools/pngfix.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngimage", "contrib/libtests/pngimage.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngimagesh", "contrib/libtests/pngimage.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngtest", "pngtest.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngtestsh", "pngtest.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngunknown", "contrib/libtests/pngunknown.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngunknownsh", "contrib/libtests/pngunknown.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "timepng", "contrib/libtests/timepng.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "timepngsh", "contrib/libtests/timepng.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngstest", "contrib/libtests/pngstest.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngstestsh", "contrib/libtests/pngstest.c");
    addExecutable(b, target, optimize, upstream, lib, pnglibconf_h, "pngvalid", "contrib/libtests/pngvalid.c");
    addExecutable(b, target, optimize, upstream, dynamic_lib, pnglibconf_h, "pngvalidsh", "contrib/libtests/pngvalid.c");
}

fn addExecutable(b: *std.Build, target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode, libpng: *std.Build.Dependency, lib: *std.Build.Step.Compile,
    pnglibconf_h: *std.Build.Step.ConfigHeader, name: []const u8, filename: []const u8) void {

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
    exe_mod.addConfigHeader(pnglibconf_h);
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
}

fn generateConf(b: *std.Build, target: std.Build.ResolvedTarget) *std.Build.Step.ConfigHeader {
    const t = target.result;
    // Some of those are just a copy paste from the header by the original autoconf
    const pnglibconf_h = .{
        .PNG_16BIT_SUPPORTED = true,
        .PNG_ALIGNED_MEMORY_SUPPORTED = true,
        .PNG_ARM_NEON_API_SUPPORTED = have_arm_feat(t, .neon) or have_aarch64_feat(t, .neon),
        .PNG_ARM_NEON_CHECK_SUPPORTED = have_arm_feat(t, .neon) or have_aarch64_feat(t, .neon),
        .PNG_BENIGN_ERRORS_SUPPORTED = true,
        .PNG_BENIGN_READ_ERRORS_SUPPORTED = true,
        .PNG_BENIGN_WRITE_ERRORS_SUPPORTED = false,
        .PNG_BUILD_GRAYSCALE_PALETTE_SUPPORTED = true,
        .PNG_CHECK_FOR_INVALID_INDEX_SUPPORTED = true,
        .PNG_COLORSPACE_SUPPORTED = true,
        .PNG_CONSOLE_IO_SUPPORTED = true,
        .PNG_CONVERT_tIME_SUPPORTED = true,
        // FIXME
        // # include <zlib.h>
        // #if ZLIB_VERNUM < 0x1290
        // # define PNG_NO_DISABLE_ADLER32_CHECK
        // #endif
        .PNG_DISABLE_ADLER32_CHECK_SUPPORTED = false,
        .PNG_EASY_ACCESS_SUPPORTED = true,
        .PNG_ERROR_NUMBERS_SUPPORTED = false,
        .PNG_ERROR_TEXT_SUPPORTED = true,
        .PNG_FIXED_POINT_SUPPORTED = true,
        .PNG_FLOATING_ARITHMETIC_SUPPORTED = true,
        .PNG_FLOATING_POINT_SUPPORTED = true,
        .PNG_FORMAT_AFIRST_SUPPORTED = true,
        .PNG_FORMAT_BGR_SUPPORTED = true,
        .PNG_GAMMA_SUPPORTED = true,
        .PNG_GET_PALETTE_MAX_SUPPORTED = true,
        .PNG_HANDLE_AS_UNKNOWN_SUPPORTED = true,
        .PNG_INCH_CONVERSIONS_SUPPORTED = true,
        .PNG_INFO_IMAGE_SUPPORTED = true,
        .PNG_IO_STATE_SUPPORTED = true,
        .PNG_MIPS_MMI_API_SUPPORTED = have_mips_feat(t, .mips32) and have_mips_feat(t, .soft_float),
        .PNG_MIPS_MMI_CHECK_SUPPORTED = have_mips_feat(t, .mips32) and have_mips_feat(t, .soft_float),
        .PNG_MIPS_MSA_API_SUPPORTED = have_mips_feat(t, .msa),
        .PNG_MIPS_MSA_CHECK_SUPPORTED = have_mips_feat(t, .msa),
        .PNG_MNG_FEATURES_SUPPORTED = true,
        .PNG_POINTER_INDEXING_SUPPORTED = true,
        .PNG_POWERPC_VSX_API_SUPPORTED = have_powerpc_feat(t, .vsx),
        .PNG_POWERPC_VSX_CHECK_SUPPORTED = have_powerpc_feat(t, .vsx),
        .PNG_PROGRESSIVE_READ_SUPPORTED = true,
        .PNG_READ_16BIT_SUPPORTED = true,
        .PNG_READ_ALPHA_MODE_SUPPORTED = true,
        .PNG_READ_ANCILLARY_CHUNKS_SUPPORTED = true,
        .PNG_READ_BACKGROUND_SUPPORTED = true,
        .PNG_READ_BGR_SUPPORTED = true,
        .PNG_READ_CHECK_FOR_INVALID_INDEX_SUPPORTED = true,
        .PNG_READ_COMPOSITE_NODIV_SUPPORTED = true,
        .PNG_READ_COMPRESSED_TEXT_SUPPORTED = true,
        .PNG_READ_EXPAND_16_SUPPORTED = true,
        .PNG_READ_EXPAND_SUPPORTED = true,
        .PNG_READ_FILLER_SUPPORTED = true,
        .PNG_READ_GAMMA_SUPPORTED = true,
        .PNG_READ_GET_PALETTE_MAX_SUPPORTED = true,
        .PNG_READ_GRAY_TO_RGB_SUPPORTED = true,
        .PNG_READ_INTERLACING_SUPPORTED = true,
        .PNG_READ_INT_FUNCTIONS_SUPPORTED = true,
        .PNG_READ_INVERT_ALPHA_SUPPORTED = true,
        .PNG_READ_INVERT_SUPPORTED = true,
        .PNG_READ_OPT_PLTE_SUPPORTED = true,
        .PNG_READ_PACKSWAP_SUPPORTED = true,
        .PNG_READ_PACK_SUPPORTED = true,
        .PNG_READ_QUANTIZE_SUPPORTED = true,
        .PNG_READ_RGB_TO_GRAY_SUPPORTED = true,
        .PNG_READ_SCALE_16_TO_8_SUPPORTED = true,
        .PNG_READ_SHIFT_SUPPORTED = true,
        .PNG_READ_STRIP_16_TO_8_SUPPORTED = true,
        .PNG_READ_STRIP_ALPHA_SUPPORTED = true,
        .PNG_READ_SUPPORTED = true,
        .PNG_READ_SWAP_ALPHA_SUPPORTED = true,
        .PNG_READ_SWAP_SUPPORTED = true,
        .PNG_READ_TEXT_SUPPORTED = true,
        .PNG_READ_TRANSFORMS_SUPPORTED = true,
        .PNG_READ_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_READ_USER_CHUNKS_SUPPORTED = true,
        .PNG_READ_USER_TRANSFORM_SUPPORTED = true,
        .PNG_READ_bKGD_SUPPORTED = true,
        .PNG_READ_cHRM_SUPPORTED = true,
        .PNG_READ_cICP_SUPPORTED = true,
        .PNG_READ_cLLI_SUPPORTED = true,
        .PNG_READ_eXIf_SUPPORTED = true,
        .PNG_READ_gAMA_SUPPORTED = true,
        .PNG_READ_hIST_SUPPORTED = true,
        .PNG_READ_iCCP_SUPPORTED = true,
        .PNG_READ_iTXt_SUPPORTED = true,
        .PNG_READ_mDCV_SUPPORTED = true,
        .PNG_READ_oFFs_SUPPORTED = true,
        .PNG_READ_pCAL_SUPPORTED = true,
        .PNG_READ_pHYs_SUPPORTED = true,
        .PNG_READ_sBIT_SUPPORTED = true,
        .PNG_READ_sCAL_SUPPORTED = true,
        .PNG_READ_sPLT_SUPPORTED = true,
        .PNG_READ_sRGB_SUPPORTED = true,
        .PNG_READ_tEXt_SUPPORTED = true,
        .PNG_READ_tIME_SUPPORTED = true,
        .PNG_READ_tRNS_SUPPORTED = true,
        .PNG_READ_zTXt_SUPPORTED = true,
        .PNG_SAVE_INT_32_SUPPORTED = true,
        .PNG_SAVE_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_SEQUENTIAL_READ_SUPPORTED = true,
        .PNG_SETJMP_SUPPORTED = true,
        .PNG_SET_OPTION_SUPPORTED = true,
        .PNG_SET_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_SET_USER_LIMITS_SUPPORTED = true,
        .PNG_SIMPLIFIED_READ_AFIRST_SUPPORTED = true,
        .PNG_SIMPLIFIED_READ_BGR_SUPPORTED = true,
        .PNG_SIMPLIFIED_READ_SUPPORTED = true,
        .PNG_SIMPLIFIED_WRITE_AFIRST_SUPPORTED = true,
        .PNG_SIMPLIFIED_WRITE_BGR_SUPPORTED = true,
        .PNG_SIMPLIFIED_WRITE_STDIO_SUPPORTED = true,
        .PNG_SIMPLIFIED_WRITE_SUPPORTED = true,
        .PNG_STDIO_SUPPORTED = true,
        .PNG_STORE_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_TEXT_SUPPORTED = true,
        .PNG_TIME_RFC1123_SUPPORTED = true,
        .PNG_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_USER_CHUNKS_SUPPORTED = true,
        .PNG_USER_LIMITS_SUPPORTED = true,
        .PNG_USER_MEM_SUPPORTED = true,
        .PNG_USER_TRANSFORM_INFO_SUPPORTED = true,
        .PNG_USER_TRANSFORM_PTR_SUPPORTED = true,
        .PNG_WARNINGS_SUPPORTED = true,
        .PNG_WRITE_16BIT_SUPPORTED = true,
        .PNG_WRITE_ANCILLARY_CHUNKS_SUPPORTED = true,
        .PNG_WRITE_BGR_SUPPORTED = true,
        .PNG_WRITE_CHECK_FOR_INVALID_INDEX_SUPPORTED = true,
        .PNG_WRITE_COMPRESSED_TEXT_SUPPORTED = true,
        .PNG_WRITE_CUSTOMIZE_COMPRESSION_SUPPORTED = true,
        .PNG_WRITE_CUSTOMIZE_ZTXT_COMPRESSION_SUPPORTED = true,
        .PNG_WRITE_FILLER_SUPPORTED = true,
        .PNG_WRITE_FILTER_SUPPORTED = true,
        .PNG_WRITE_FLUSH_SUPPORTED = true,
        .PNG_WRITE_GET_PALETTE_MAX_SUPPORTED = true,
        .PNG_WRITE_INTERLACING_SUPPORTED = true,
        .PNG_WRITE_INT_FUNCTIONS_SUPPORTED = true,
        .PNG_WRITE_INVERT_ALPHA_SUPPORTED = true,
        .PNG_WRITE_INVERT_SUPPORTED = true,
        .PNG_WRITE_OPTIMIZE_CMF_SUPPORTED = true,
        .PNG_WRITE_PACKSWAP_SUPPORTED = true,
        .PNG_WRITE_PACK_SUPPORTED = true,
        .PNG_WRITE_SHIFT_SUPPORTED = true,
        .PNG_WRITE_SUPPORTED = true,
        .PNG_WRITE_SWAP_ALPHA_SUPPORTED = true,
        .PNG_WRITE_SWAP_SUPPORTED = true,
        .PNG_WRITE_TEXT_SUPPORTED = true,
        .PNG_WRITE_TRANSFORMS_SUPPORTED = true,
        .PNG_WRITE_UNKNOWN_CHUNKS_SUPPORTED = true,
        .PNG_WRITE_USER_TRANSFORM_SUPPORTED = true,
        .PNG_WRITE_WEIGHTED_FILTER_SUPPORTED = true,
        .PNG_WRITE_bKGD_SUPPORTED = true,
        .PNG_WRITE_cHRM_SUPPORTED = true,
        .PNG_WRITE_cICP_SUPPORTED = true,
        .PNG_WRITE_cLLI_SUPPORTED = true,
        .PNG_WRITE_eXIf_SUPPORTED = true,
        .PNG_WRITE_gAMA_SUPPORTED = true,
        .PNG_WRITE_hIST_SUPPORTED = true,
        .PNG_WRITE_iCCP_SUPPORTED = true,
        .PNG_WRITE_iTXt_SUPPORTED = true,
        .PNG_WRITE_mDCV_SUPPORTED = true,
        .PNG_WRITE_oFFs_SUPPORTED = true,
        .PNG_WRITE_pCAL_SUPPORTED = true,
        .PNG_WRITE_pHYs_SUPPORTED = true,
        .PNG_WRITE_sBIT_SUPPORTED = true,
        .PNG_WRITE_sCAL_SUPPORTED = true,
        .PNG_WRITE_sPLT_SUPPORTED = true,
        .PNG_WRITE_sRGB_SUPPORTED = true,
        .PNG_WRITE_tEXt_SUPPORTED = true,
        .PNG_WRITE_tIME_SUPPORTED = true,
        .PNG_WRITE_tRNS_SUPPORTED = true,
        .PNG_WRITE_zTXt_SUPPORTED = true,
        .PNG_bKGD_SUPPORTED = true,
        .PNG_cHRM_SUPPORTED = true,
        .PNG_cICP_SUPPORTED = true,
        .PNG_cLLI_SUPPORTED = true,
        .PNG_eXIf_SUPPORTED = true,
        .PNG_gAMA_SUPPORTED = true,
        .PNG_hIST_SUPPORTED = true,
        .PNG_iCCP_SUPPORTED = true,
        .PNG_iTXt_SUPPORTED = true,
        .PNG_mDCV_SUPPORTED = true,
        .PNG_oFFs_SUPPORTED = true,
        .PNG_pCAL_SUPPORTED = true,
        .PNG_pHYs_SUPPORTED = true,
        .PNG_sBIT_SUPPORTED = true,
        .PNG_sCAL_SUPPORTED = true,
        .PNG_sPLT_SUPPORTED = true,
        .PNG_sRGB_SUPPORTED = true,
        .PNG_tEXt_SUPPORTED = true,
        .PNG_tIME_SUPPORTED = true,
        .PNG_tRNS_SUPPORTED = true,
        .PNG_zTXt_SUPPORTED = true,
        // settings
        .PNG_API_RULE = 0,
        .PNG_DEFAULT_READ_MACROS = 1,
        .PNG_GAMMA_THRESHOLD_FIXED = 5000,
        .PNG_IDAT_READ_SIZE = .PNG_ZBUF_SIZE,
        .PNG_INFLATE_BUF_SIZE = 1024,
        .PNG_LINKAGE_API = .@"extern",
        .PNG_LINKAGE_CALLBACK = .@"extern",
        .PNG_LINKAGE_DATA = .@"extern",
        .PNG_LINKAGE_FUNCTION = .@"extern",
        .PNG_MAX_GAMMA_8 = 11,
        .PNG_QUANTIZE_BLUE_BITS = 5,
        .PNG_QUANTIZE_GREEN_BITS = 5,
        .PNG_QUANTIZE_RED_BITS = 5,
        .PNG_TEXT_Z_DEFAULT_COMPRESSION = -1,
        .PNG_TEXT_Z_DEFAULT_STRATEGY = 0,
        .PNG_USER_CHUNK_CACHE_MAX = 1000,
        .PNG_USER_CHUNK_MALLOC_MAX = 8000000,
        .PNG_USER_HEIGHT_MAX = 1000000,
        .PNG_USER_WIDTH_MAX = 1000000,
        .PNG_ZBUF_SIZE = 8192,
        .PNG_ZLIB_VERNUM = 0x1300,
        .PNG_Z_DEFAULT_COMPRESSION = -1,
        .PNG_Z_DEFAULT_NOFILTER_STRATEGY = 0,
        .PNG_Z_DEFAULT_STRATEGY = 1,
        .PNG_sCAL_PRECISION = 5,
        .PNG_sRGB_PROFILE_CHECKS = 2,
    };

    return b.addConfigHeader(.{
        .style = .blank,
        .include_path = "pnglibconf.h",
    }, pnglibconf_h);
}

fn have_x86_feat(t: std.Target, feat: std.Target.x86.Feature) bool {
    return switch (t.cpu.arch) {
        .x86, .x86_64 => std.Target.x86.featureSetHas(t.cpu.features, feat),
        else => false,
    };
}

fn have_arm_feat(t: std.Target, feat: std.Target.arm.Feature) bool {
    return switch (t.cpu.arch) {
        .arm, .armeb => std.Target.arm.featureSetHas(t.cpu.features, feat),
        else => false,
    };
}

fn have_aarch64_feat(t: std.Target, feat: std.Target.aarch64.Feature) bool {
    return switch (t.cpu.arch) {
        .aarch64,
        .aarch64_be,
        => std.Target.aarch64.featureSetHas(t.cpu.features, feat),

        else => false,
    };
}

fn have_mips_feat(t: std.Target, feat: std.Target.mips.Feature) bool {
    return switch (t.cpu.arch) {
        .mips,
        => std.Target.mips.featureSetHas(t.cpu.features, feat),

        else => false,
    };
}

fn have_powerpc_feat(t: std.Target, feat: std.Target.powerpc.Feature) bool {
    return switch (t.cpu.arch) {
        .powerpc,
        => std.Target.powerpc.featureSetHas(t.cpu.features, feat),

        else => false,
    };
}
