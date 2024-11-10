#include "memory.hpp"

#include <iostream>
#include <vector>

namespace vram {
    namespace memory {
        // Connection with OpenCL
        bool ready = false;
        bool has_fillbuffer = false; // supports the FillBuffer API (platform is version 1.2 or higher)
        cl::Context context;
        cl::Device device;

        int numQueues = 1;
        int currentQueueIndex = 0;
        std::vector<cl::CommandQueue> queues;
        // cl::CommandQueue queue;

        static cl::CommandQueue& GetQueue() {
            cl::CommandQueue& queue = queues[currentQueueIndex++];
        
            if(currentQueueIndex >= numQueues) {
                currentQueueIndex = 0;
            }

            return queue;
        }

        cl::Buffer zero_buffer; // used to clear buffers on pre-1.2 platforms

        std::vector<block*> pool;
        int total_blocks = 0;

        size_t device_num;

        // Fill buffer with zeros
        static int clear_buffer(cl::Buffer& buf) {
            if (has_fillbuffer)
                return GetQueue().enqueueFillBuffer(buf, 0, 0, block::size, nullptr, nullptr);
            else
                return GetQueue().enqueueCopyBuffer(zero_buffer, buf, 0, 0, block::size, nullptr, nullptr);
        }

        // Find platform with OpenCL capable GPU
        static bool init_opencl() {
            if (ready) return true;

            std::vector<cl::Platform> platforms;
            cl::Platform::get(&platforms);
            if (platforms.size() == 0) return false;

            auto index = device_num;
            for (auto& platform : platforms) {
                std::vector<cl::Device> gpu_devices;
                platform.getDevices(CL_DEVICE_TYPE_GPU, &gpu_devices);
                if (index >= gpu_devices.size())
                {
                    index -= gpu_devices.size();
                    continue;
                }

                device = gpu_devices[index];
                context = cl::Context(gpu_devices);

                
                // TODO: Queury the max number of queues we can make
                // numQueues = 
                // queue = cl::CommandQueue(context, device);
                for(int i = 0; i < numQueues; ++i) {
                    cl_command_queue_properties props = CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE | CL_QUEUE_PRIORITY_HIGH_KHR | CL_QUEUE_THROTTLE_HIGH_KHR;
                    queues.push_back(cl::CommandQueue(context, device, props)); 
                    printf("Created cl::CommandQueue #%d\n", i);
                }

                cl_uint version = cl::detail::getPlatformVersion(platform());

                if (version >= (1 << 16 | 2))
                    has_fillbuffer = true;

                if (!has_fillbuffer) {
                    char zero_data[block::size] = {};
                    int r;
                    zero_buffer = cl::Buffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, block::size, zero_data, &r);
                    if (r != CL_SUCCESS) return false;
                }

                return true;
            }

            return false;
        }

        // Called for asynchronous writes to clean up the data copy
        static void CL_CALLBACK async_write_dealloc(cl_event, cl_int, void* data) {
            delete [] reinterpret_cast<char*>(data);
        }

        bool is_available() {
            return (ready = init_opencl());
        }

        void set_device(size_t device) {
            device_num = device;
        }

        std::vector<std::string> list_devices() {
            std::vector<std::string> device_names;

            std::vector<cl::Platform> platforms;
            cl::Platform::get(&platforms);

            for (auto& platform : platforms) {
                std::vector<cl::Device> gpu_devices;
                platform.getDevices(CL_DEVICE_TYPE_GPU, &gpu_devices);

                for (auto& device : gpu_devices) {
                    device_names.push_back(device.getInfo<CL_DEVICE_NAME>());
                }
            }

            return device_names;
        }

        int pool_size() {
            return total_blocks;
        }

        int pool_available() {
            return pool.size();
        }

        size_t increase_pool(size_t size) {
            int block_count = 1 + (size - 1) / block::size;
            int r;


            // Warn(Sam): if size is larger than `ulimit -l` kilobytes then
            //            this will segfault. Default `ulimit -l` is 65K (65MB)
            for (int i = 0; i < block_count; i++) {
                cl::Buffer buf(context, CL_MEM_READ_WRITE, block::size, nullptr, &r);
                block* pBlock = new block(buf);

                if (r == CL_SUCCESS && clear_buffer(buf) == CL_SUCCESS) {
                    pool.push_back(pBlock);
                    total_blocks++;
                } else {
                    return i * block::size;
                }
            }

            return block_count * block::size;
        }

        block_ref allocate() {

            // TODO: HERE!!!! TEST IF THIS CAUSES A BUG WHEN two disk mark tests are run back to back
            // TODO: Figure out what is causing CreateThread to be invoked during crystal disk mark writes.
            //       right now they are the bottleneck with ~80% of the time being spent there when using 4K block. The next
            //       bottle neck is opencl writes to buffer which take ~15% of cpu. Strangely this bottlenecks to opencl using 
            //       ~70% of the time and create thread using ~20% of cpu time when using 128K blocks....  
            // TODO: bench with 4K and 128K block size to see if 128K blocksize speedup is related to CPU or GPU bottleneck
            //       right now 4K block sizes give ~120MB/s seq read and 128K blocksize gives ~1GB/s read
            if (pool.size() != 0) {

                block* pBlock = pool.back();
                pool.pop_back();
                
                return block_ref(pBlock);
            } else {
                return nullptr;
            }
        }

        block::block(cl::Buffer buf) {
            buffer = buf;
        }

        block::~block() {
            pool.push_back(this);
        }

        void block::read(off_t offset, size_t size, void* data) const {
            if (dirty) {
                memset(data, 0, size);
            } else {
                // Queue is configured for in-order execution, so writes before this
                // are guaranteed to be completed first
                GetQueue().enqueueReadBuffer(buffer, true, offset, size, data, nullptr, nullptr);
            }
        }

        void block::write(off_t offset, size_t size, const void* data, bool async) {
            
            // TODO: Figure out if we ever need this or if it can be faster.
            // async = false;
            
            // If this block has not been written to yet, and this call doesn't
            // overwrite the entire block, clear with zeros first
            if (dirty && size != block::size) {
                clear_buffer(buffer);
            }

            if (async) {
                char* data_copy = new char[size];
                memcpy(data_copy, data, size);
                data = data_copy;
            }

            cl::Event event;
            GetQueue().enqueueWriteBuffer(buffer, !async, offset, size, data, nullptr, &event);

            if (async) {
                event.setCallback(CL_COMPLETE, async_write_dealloc, const_cast<void*>(data));
            }

            last_write = event;
            dirty = false;
        }

        void block::sync() {
            last_write.wait();
        }
    }
}
