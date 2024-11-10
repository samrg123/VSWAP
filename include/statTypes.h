#pragma once

#include <sys/stat.h>

#if !defined(S_IFLNK)
#define S_IFLNK                         0120000
#endif
#if !defined(S_IFSOCK)
#define S_IFSOCK                        0140000
#endif
#if !defined(S_IFIFO)
#define S_IFIFO                         0010000
#endif
