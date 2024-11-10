CC = g++
CFLAGS = -pg -Wall -Wpedantic -Werror -std=c++17 $(shell pkg-config fuse3 --cflags) -I include/
LDFLAGS = -flto $(shell pkg-config fuse3 --libs) -l OpenCL

ifeq ($(DEBUG), 1)
	CFLAGS += -g -DDEBUG -O0
	# CFLAGS += -g -O0
	LDFLAGS += -Xlinker -Map=vramfs.map
else
	CFLAGS += -g -march=native -O2 -flto
endif

# dependicies = Makefile include/*.hpp include/CL/*.hpp
# objects = build/util.o build/memory.o build/entry.o build/file.o build/dir.o build/symlink.o build/vramfs.o

# bin/vramfs: $(dependicies) $(objects) | bin
# 	$(CC) -o $@ $(objects) $(LDFLAGS)

# build bin:
# 	@mkdir -p $@

# build/%.o: src/%.cpp $(dependicies) | build 
# 	$(CC) $(CFLAGS) -c -o $@ $<

# .PHONY: clean
# clean:
# 	rm -rf build/ bin/



# CC = g++
# CFLAGS = -pg -Wall -Wpedantic -Werror -std=c++11 $(shell pkg-config fuse3 --cflags) -I include/
# LDFLAGS = -pg -flto $(shell pkg-config fuse3 --libs) -l OpenCL

# ifeq ($(DEBUG), 1)
# 	# CFLAGS += -g -DDEBUG -Wall -Werror -std=c++11 -O0
# 	CFLAGS += -g -Wall -Werror -std=c++11 -O0
# 	LDFLAGS += -Xlinker -Map=vramfs.map
# else
# 	CFLAGS += -march=native -O2 -flto
# endif

SRC_FILES = src/*.cpp
dependicies = $(SRC_FILES) Makefile include/*.hpp include/CL/*.hpp
# objects = build/util.o build/memory.o build/entry.o build/file.o build/dir.o build/symlink.o build/vramfs.o


# g++ -Wall -Wpedantic -Werror -std=c++11 -I/usr/include/fuse3  -I include/ -march=native -O2 -flto 
# -c -o build/vramfs.o src/vramfs.cpp
# g++ -o bin/vramfs build/util.o build/memory.o build/entry.o build/file.o build/dir.o build/symlink.o build/vramfs.o -flto -lfuse3 -lpthread  -l OpenCL

bin/vramfs: $(dependicies) |bin
	$(CC) $(CFLAGS) $(SRC_FILES) -o $@ $(LDFLAGS)   

build bin:
	@mkdir -p $@


.PHONY: clean
clean:
	rm -rf build/ bin/
	rm -f gmon.out *.map *.profile
