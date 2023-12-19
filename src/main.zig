const std = @import("std");
const Server = @import("Server.zig");

extern fn swc_is_valid_javascript(c: [*]const u8) bool;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const alloc = gpa.allocator();
    //
    // var server = try Server.create(alloc);
    // try server.start();

    std.debug.print("exit success!", .{});
    std.process.exit(0);
}

test {
    // const map = std.ComptimeStringMap([]const u8, .{
    //     .{ "x-data", @embedFile("./alpinejs/attributes/x-data.md") },
    // });
    //
    // std.debug.print("x-data: {s}\n", .{map.get("x-data").?});

    // TODO: figure out why this doesn't work
    const js = "const x = 1234567890;";
    const valid = swc_is_valid_javascript(js);

    try std.testing.expect(valid);

    // try std.testing.expectEqualStrings("1234567890", map.get("x-data").?);
}
