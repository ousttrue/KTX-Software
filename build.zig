const std = @import("std");

const FLAGS = [_][]const u8{
    "-DKTX_API=__declspec(dllexport)",
    "-DBASISU_SUPPORT_OPENCL=0",
    "-DKTX_FEATURE_WRITE",
    "-DKTX_FEATURE_KTX1",
    "-DKTX_FEATURE_KTX2",
    "-D_CLANG_DISABLE_CRT_DEPRECATION_WARNINGS",
    // "-DKTX_FEATURE_VK_UPLOAD",
    // "-DKTX_FEATURE_GL_UPLOAD",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fmt = buildFmt(b, target, optimize);
    const ktx = buildKtx(b, target, optimize, fmt);
    b.installArtifact(ktx);

    {
        // ktxtool
        const exe = b.addExecutable(.{
            .name = "ktxtool",
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(.{
            .root = b.path(""),
            .files = &.{
                "tools/ktx/ktx_main.cpp",
            },
            .flags = &(FLAGS),
        });
        const install = b.addInstallArtifact(exe, .{});
        b.step("ktxtool", "build ktxtool").dependOn(&install.step);

        // stdafx.h
        exe.addIncludePath(b.path("utils"));
        // glm
        exe.addIncludePath(b.path("other_include"));
        exe.linkLibrary(fmt);
        exe.addIncludePath(b.path("external/cxxopts/include"));
        //
        exe.linkLibrary(ktx);
    }
}

fn buildKtx(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    fmt: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const lib = b.addSharedLibrary(.{
        .name = "ktx",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibCpp();
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("utils"));
    lib.addIncludePath(b.path("other_include"));
    lib.addIncludePath(b.path("lib"));
    lib.addCSourceFiles(.{
        .files = &.{
            "lib/basis_transcode.cpp",
            "lib/miniz_wrapper.cpp",
            "lib/checkheader.c",
            "lib/etcunpack.cxx",
            "lib/filestream.c",
            "lib/hashlist.c",
            "lib/info.c",
            "lib/memstream.c",
            "lib/strings.c",
            "lib/swap.c",
            "lib/texture.c",
            "lib/texture1.c",
            "lib/texture2.c",
            "lib/vkformat_check.c",
            "lib/vkformat_str.c",
            "lib/vkformat_typesize.c",
            "external/etcdec/etcdec.cxx",
            // encoder
            "lib/basis_encode.cpp",
            "lib/astc_codec.cpp",
            "lib/writer1.c",
            "lib/writer2.c",
            // ktxtool
            "tools/ktx/command.cpp",
            "tools/ktx/command_compare.cpp",
            "tools/ktx/command_create.cpp",
            "tools/ktx/command_deflate.cpp",
            "tools/ktx/command_encode.cpp",
            "tools/ktx/command_extract.cpp",
            "tools/ktx/command_help.cpp",
            "tools/ktx/command_info.cpp",
            "tools/ktx/command_transcode.cpp",
            "tools/ktx/command_validate.cpp",
            "tools/ktx/validate.cpp",
            "tools/ktx/transcode_utils.cpp",
        },
        .flags = &(FLAGS ++ .{"-DLIBKTX"}),
    });
    lib.installHeader(b.path("include/ktx.h"), "ktx.h");
    lib.installHeader(b.path("lib/ktxint.h"), "ktxint.h");
    lib.installHeader(b.path("lib/basis_sgd.h"), "basis_sgd.h");
    lib.installHeader(b.path("lib/texture2.h"), "texture2.h");
    lib.installHeader(b.path("lib/texture.h"), "texture.h");
    lib.installHeader(b.path("lib/formatsize.h"), "formatsize.h");
    lib.installHeader(b.path("lib/texture_funcs.inl"), "texture_funcs.inl");

    // exe.addIncludePath(b.path("utils"));

    const dfd = buildDfd(b, target, optimize);
    lib.linkLibrary(dfd);

    const basisu = buildBasisu(b, target, optimize);
    lib.linkLibrary(basisu);

    const zstd = buildZstd(b, target, optimize);
    lib.linkLibrary(zstd);

    const astc = buildAstc(b, target, optimize);
    lib.linkLibrary(astc);

    const imageio = buildImageio(b, target, optimize);

    lib.linkLibrary(imageio);
    lib.linkLibrary(fmt);
    imageio.linkLibrary(dfd);
    imageio.addIncludePath(basisu.getEmittedIncludeTree().path(b, "basisu"));
    imageio.addIncludePath(dfd.getEmittedIncludeTree().path(b, "dfdutils"));

    // exe.linkLibrary(imageio);
    // exe.addIncludePath(b.path("other_include"));

    imageio.linkLibrary(fmt);
    // exe.linkLibrary(fmt);
    lib.addIncludePath(b.path("external/cxxopts/include"));

    lib.installHeadersDirectory(basisu.getEmittedIncludeTree(), "", .{});
    lib.installHeadersDirectory(astc.getEmittedIncludeTree(), "", .{});
    lib.installHeadersDirectory(dfd.getEmittedIncludeTree(), "", .{});
    lib.installHeadersDirectory(imageio.getEmittedIncludeTree(), "", .{});
    return lib;
}

fn buildFmt(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "fmt",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibCpp();
    lib.addCSourceFiles(.{
        .root = b.path("external/fmt/src"),
        .files = &.{
            "format.cc",
            "os.cc",
            "fmt.cc",
        },
        .flags = &.{
            "-std=c++20",
            "-D_CLANG_DISABLE_CRT_DEPRECATION_WARNINGS",
        },
    });
    lib.addIncludePath(b.path("external/fmt/include"));
    lib.installHeadersDirectory(b.path("external/fmt/include/fmt"), "fmt", .{});
    return lib;
}

fn buildImageio(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "imageio",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibCpp();
    lib.addIncludePath(b.path("tools/imageio"));
    lib.addIncludePath(b.path("external/astc-encoder/Source/ThirdParty"));
    lib.addCSourceFiles(.{
        .root = b.path("tools/imageio"),
        .files = &.{
            "imageinput.cc",
            "imageio.cc",
            "imageoutput.cc",
            "exr.imageio/exrinput.cc",
            "jpg.imageio/jpginput.cc",
            "npbm.imageio/npbminput.cc",
            "png.imageio/lodepng.cc",
            "png.imageio/pnginput.cc",
            "png.imageio/pngoutput.cc",
        },
        .flags = &.{"-DLIBKTX"},
    });
    lib.installHeader(b.path("tools/imageio/imageio.h"), "imageio.h");
    lib.installHeader(b.path("tools/imageio/imageio_utility.h"), "imageio_utility.h");
    lib.installHeader(b.path("tools/imageio/formatdesc.h"), "formatdesc.h");
    lib.installHeader(b.path("tools/imageio/image.hpp"), "image.hpp");
    lib.installHeader(b.path("tools/imageio/imagecodec.hpp"), "imagecodec.hpp");
    lib.installHeader(b.path("tools/imageio/imagespan.hpp"), "imagespan.hpp");
    lib.installHeader(b.path("tools/imageio/png.imageio/lodepng.h"), "png.imageio/lodepng.h");

    lib.addIncludePath(b.path("utils"));
    lib.addIncludePath(b.path("other_include"));

    return lib;
}

fn buildAstc(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "astc",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibCpp();
    lib.addCSourceFiles(.{
        .root = b.path("external/astc-encoder/Source"),
        .files = &.{
            "astcenc_averages_and_directions.cpp",
            "astcenc_block_sizes.cpp",
            "astcenc_color_quantize.cpp",
            "astcenc_color_unquantize.cpp",
            "astcenc_compress_symbolic.cpp",
            "astcenc_compute_variance.cpp",
            "astcenc_decompress_symbolic.cpp",
            "astcenc_diagnostic_trace.cpp",
            "astcenc_entry.cpp",
            "astcenc_find_best_partitioning.cpp",
            "astcenc_ideal_endpoints_and_weights.cpp",
            "astcenc_image.cpp",
            "astcenc_integer_sequence.cpp",
            "astcenc_mathlib.cpp",
            "astcenc_mathlib_softfloat.cpp",
            "astcenc_partition_tables.cpp",
            "astcenc_percentile_tables.cpp",
            "astcenc_pick_best_endpoint_format.cpp",
            "astcenc_quantization.cpp",
            "astcenc_symbolic_physical.cpp",
            "astcenc_weight_align.cpp",
            "astcenc_weight_quant_xfer_tables.cpp",
        },
    });
    // lib.installHeader(b.path("external/astc-encoder/Source/astcenc.h"), "astc-encoder/Source/astcenc.h");
    lib.installHeadersDirectory(b.path("external/astc-encoder/Source"), "astc-encoder/Source", .{});
    return lib;
}

fn buildZstd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "zstd",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "external/basisu/zstd/zstd.c",
        },
    });
    lib.installHeader(b.path("external/basisu/zstd/zstd.h"), "zstd.h");
    lib.installHeader(b.path("other_include/zstd_errors.h"), "zstd_errors.h");
    return lib;
}

fn buildBasisu(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "basisu",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibCpp();
    lib.addCSourceFiles(.{
        .root = b.path("external/basisu"),
        .files = &.{
            "transcoder/basisu_transcoder.cpp",
            "encoder/jpgd.cpp",
            // "encoder/pvpngreader.cpp",
            "encoder/basisu_backend.cpp",
            "encoder/basisu_basis_file.cpp",
            "encoder/basisu_bc7enc.cpp",
            "encoder/basisu_comp.cpp",
            "encoder/basisu_enc.cpp",
            "encoder/basisu_etc.cpp",
            "encoder/basisu_frontend.cpp",
            "encoder/basisu_gpu_texture.cpp",
            "encoder/basisu_kernels_sse.cpp",
            "encoder/basisu_opencl.cpp",
            "encoder/basisu_pvrtc1_4.cpp",
            "encoder/basisu_resample_filters.cpp",
            "encoder/basisu_resampler.cpp",
            "encoder/basisu_ssim.cpp",
            "encoder/basisu_uastc_enc.cpp",
        },
        .flags = &(FLAGS ++ .{"-DLIBKTX"}),
    });
    lib.installHeadersDirectory(b.path("external/basisu"), "basisu", .{});

    return lib;
}

fn buildDfd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "dfd",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addCSourceFiles(.{
        .files = &.{
            "external/dfdutils/createdfd.c",
            "external/dfdutils/colourspaces.c",
            "external/dfdutils/interpretdfd.c",
            "external/dfdutils/printdfd.c",
            "external/dfdutils/queries.c",
            "external/dfdutils/vk2dfd.c",
        },
        .flags = &(FLAGS ++ .{"-DLIBKTX"}),
    });
    lib.addIncludePath(b.path("include"));
    lib.installHeader(b.path("include/KHR/khr_df.h"), "KHR/khr_df.h");
    lib.installHeader(b.path("external/dfdutils/dfd.h"), "dfdutils/dfd.h");
    lib.addIncludePath(b.path("lib"));
    lib.installHeader(b.path("lib/vkformat_enum.h"), "vkformat_enum.h");
    return lib;
}
