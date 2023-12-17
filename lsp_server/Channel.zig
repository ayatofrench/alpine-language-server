const std = @import("std");
const Fifo = std.fifo.LinearFifo;

pub fn Channel(comptime T: type) type {
    return struct {
        fifo: Fifo(T, .Dynamic),
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},

        const Self = @This();

        pub fn init(self: *Self, allocator: std.mem.Allocator) void {
            self.* = Self{
                .fifo = Fifo(T, .Dynamic).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.fifo.deinit();
        }

        pub fn try_push(self: *Self, item: T) !void {
            {
                self.mutex.lock();
                defer self.mutex.unlock();

                try self.fifo.writeItem(item);
            }

            self.cond.signal();
        }

        pub fn try_pop(self: *Self, block: bool) !?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) {
                return self.fifo.readItem() orelse {
                    if (!block) return null;

                    self.cond.wait(&self.mutex);
                    continue;
                };
            }
        }
    };
}
