const std = @import("std");
const Server = @import("Server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const server = try Server.create(alloc);
    try server.start();

    std.debug.print("exit success!", .{});
    std.process.exit(0);
}
