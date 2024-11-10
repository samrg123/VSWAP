#include "entry.hpp"
#include "util.hpp"

namespace vram {
    namespace entry {
        int entry_count = 0;

        int count() {
            return entry_count;
        }

        entry_t::entry_t() {
            auto t = util::time();

            _atime = t;
            _mtime = t;
            _ctime = t;

            entry_count++;
        }

        entry_t::~entry_t() {
            entry_count--;
        }

        void entry_t::link(dir_ptr parent, const string& name) {
            _parent = parent;
            _name = name;

            if (parent) {
                parent->_children[name] = shared_from_this();
                parent->mtime(util::time());
            }
        }

        dir_ptr entry_t::parent() const {
            return _parent;
        }

        const string& entry_t::name() const {
            return _name;
        }

        fuse_timespec entry_t::atime() const {
            return _atime;
        }

        fuse_timespec entry_t::mtime() const {
            return _mtime;
        }

        fuse_timespec entry_t::ctime() const {
            return _ctime;
        }

        fuse_fuse_mode_t entry_t::mode() const {
            return _mode;
        }

        fuse_fuse_uid_t entry_t::user() const {
            return _user;
        }

        fuse_gid_t entry_t::group() const {
            return _group;
        }

        void entry_t::atime(fuse_timespec t) {
            _atime = t;
            ctime(util::time());
        }

        void entry_t::mtime(fuse_timespec t) {
            _mtime = t;
            ctime(util::time());
        }

        void entry_t::ctime(fuse_timespec t) {
            _ctime = t;
        }

        void entry_t::mode(fuse_fuse_mode_t mode) {
            _mode = mode;
            ctime(util::time());
        }

        void entry_t::user(fuse_fuse_uid_t user) {
            _user = user;
            ctime(util::time());
        }

        void entry_t::group(fuse_gid_t group) {
            _group = group;
            ctime(util::time());
        }

        void entry_t::unlink() {
            if (_parent) {
                _parent->_children.erase(_name);
                _parent->mtime(util::time());
            }
        }

        void entry_t::move(dir_ptr new_parent, const string& new_name) {
            if (_parent) {
                _parent->_children.erase(_name);
                _parent->mtime(util::time());
            }

            _parent = new_parent;
            _name = new_name;

            ctime(util::time());

            new_parent->_children[new_name] = shared_from_this();
            new_parent->mtime(util::time());
        }
    }
}
