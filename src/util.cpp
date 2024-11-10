#include "util.hpp"

#include <time.h>

namespace vram {
    namespace util {

        fuse_timespec timeSpec2FuseTimespec(timespec tv) {
            fuse_timespec ftv;
            ftv.tv_sec = tv.tv_sec;
            ftv.tv_nsec = tv.tv_nsec;
            return ftv;
        }

        fuse_timespec time() {
            timespec tv;
            timespec_get(&tv, TIME_UTC);
            return timeSpec2FuseTimespec(tv);
        }

        void split_file_path(const string& path, string& dir, string& file) {
            size_t p = path.rfind("/");

            if (p == string::npos) {
                dir = "";
                file = path;
            } else {
                dir = path.substr(0, p);
                file = path.substr(p + 1);
            }

            if (dir.size() == 0) dir = "/";
        }
    }
}
