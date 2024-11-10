#ifndef VRAM_UTIL_HPP
#define VRAM_UTIL_HPP

/*
 * Utility functions
 */

#define FUSE_USE_VERSION 30
#include <fuse3/fuse.h>

#include <iostream>
#include <string>

using std::string;

namespace vram {
    namespace util {
        // Error function that can be combined with a return statement to return *ret*
        template<typename T>
        T fatal_error(const string& error, T ret) {
            std::cerr << "error: " << error << std::endl;
            fuse_exit(fuse_get_context()->fuse);
            return ret;
        }

        // converts c timespec to fuse_timespec
        fuse_timespec timeSpec2FuseTimespec(timespec tv);

        // Get current time with nanosecond precision
        fuse_timespec time();

        // Split path/to/file.txt into "path/to" and "file.txt"
        void split_file_path(const string& path, string& dir, string& file);
    }
}

#endif
