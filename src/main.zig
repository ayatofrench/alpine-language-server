const std = @import("std");
const Server = @import("Server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var server = try Server.create(alloc);
    try server.start();

    std.debug.print("exit success!", .{});
    std.process.exit(0);
}

// test {
//     const map = std.ComptimeStringMap([]const u8, .{
//         .{ "x-data", @embedFile("./alpinejs/attributes/x-data.md") },
//     });
//
//     std.debug.print("x-data: {s}\n", .{map.get("x-data").?});
//
//     // try std.testing.expectEqualStrings("1234567890", map.get("x-data").?);
// }
