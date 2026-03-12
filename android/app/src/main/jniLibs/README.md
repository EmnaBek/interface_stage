Place your OpenJPEG shared libraries here for each ABI.

For example:

    jniLibs/armeabi-v7a/libopenjp2.so
    jniLibs/arm64-v8a/libopenjp2.so

The `openjp2wrapper` CMake script links against `openjp2` and the wrapper
library is built automatically. In order to compile the wrapper you need
both the OpenJPEG header **and** library for each ABI.

Two options:

1. **Prebuilt binaries**
   - Place `libopenjp2.so` for each ABI in this directory tree:
     `jniLibs/<abi>/libopenjp2.so` (e.g. `jniLibs/arm64-v8a/libopenjp2.so`).
   - Place the header file `openjpeg.h` under `jniLibs/include/` (or another
     include path), so CMake can find it during configuration.
   - CMake will detect the include path and library and compile with
     `USE_OPENJPEG=1` enabled. If either header or library is missing, a
     warning is shown and the JNI function becomes a no-op stub (the app will
     still build, but native decoding is disabled).

2. **Build from source**
   - Clone the OpenJPEG repository under `android/app/src/main/cpp/openjpeg`
     (or any other location) and uncomment the `add_subdirectory(openjpeg)`
     lines in `CMakeLists.txt`. This will compile the codec as part of the
     Android build and automatically provide headers and a static library.

See `CMakeLists.txt` for details on the detection logic and the `NO_OPENJPEG`
compile-time flag used when the library isn't available.
