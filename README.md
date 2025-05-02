# libpng

This is [libpng](http://www.libpng.org/pub/png/libpng.html),
packaged for [Zig](https://ziglang.org/).

This repository is in not way affiliated with the libpng project.

## How to use it

First, update your `build.zig.zon`:

```
zig fetch --save https://github.com/allyourcodebase/libpng/archive/refs/tags/1.6.48.tar.gz
```

Next, add this snippet to your `build.zig` script:

```zig
const libpng_dep = b.dependency("libpng", .{
    .target = target,
    .optimize = optimize,
});
your_compilation.linkLibrary(libpng_dep.artifact("png16"));
```

This will provide libpng as a static library to `your_compilation`.
