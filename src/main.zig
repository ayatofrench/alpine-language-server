const std = @import("std");
const Connection = @import("lib/lsp_server/Connection.zig").Connection;
const Message = @import("lib/lsp_server/Message.zig").Message;
const types = @import("lsp_types.zig");
const util = @import("lib/lsp_server/util.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    var conn = try Connection.create(alloc, .stdio);

    const params = try conn.init(types.ServerCapabilities{
        .definitionProvider = .{
            .bool = true,
        },
    });
    _ = params;

    const json = "{\"method\": \"initialize\", \"id\": 1, \"params\": {\"capabilities\": {}}}";
    // const json = "{\"method\": \"shutdown\", \"id\": 1, \"params\": {}}";
    // const json = '{"id": "hello", "method": "method", "params": {}}';
    // _ = json;
    const jsonMsg = try std.json.parseFromSlice(Message, gpa.allocator(), json, .{
        .ignore_unknown_fields = false,
        .max_value_len = null,
    });
    defer {
        jsonMsg.deinit();
        conn.deinit();
        alloc.destroy(conn);
        arena.deinit();
    }

    var result = try util.toJsonValue(arena.allocator(), jsonMsg.value);

    // _ = try result.jsonStringify(writer);

    // std.debug.print("{any}", .{result.object.get("params")});
    var msg = Message{
        .response = .{
            .id = types.RequestId{ .integer = 123 },
            .result = result,
            .@"error" = null,
        },
    };
    _ = msg;

    // std.debug.print("Message: {any}\n", .{jsonMsg.value});

    // try conn.sender.try_push(msg);

    // std.time.sleep(100);
    // try conn.sender.try_push(msg);

    const RequestMethods = std.meta.Tag(Message.Request.Params);

    // while (conn.running()) {
    // const message = try conn.receiver.try_pop(true);

    while (try conn.receiver.try_pop(true)) |message| {
        switch (std.meta.stringToEnum(RequestMethods, message.request.method).?) {
            .shutdown => {
                try conn.sender.try_push(Message{ .response = .{
                    .id = types.RequestId{ .integer = 123 },
                    .result = result,
                    .@"error" = null,
                } });
                conn.setStatus(.exiting_success);
                break;
            },
            .@"textDocument/definition" => {
                try conn.sender.try_push(Message{ .response = .{
                    .id = types.RequestId{ .integer = 123 },
                    .result = std.json.Value{ .integer = 123 },
                    .@"error" = null,
                } });
            },
            else => {
                conn.setStatus(.exiting_success);
                break;
            },
        }
    }
    //
    conn.setStatus(.exiting_success);
    // break;
    // }

    // var buffer = std.ArrayListUnmanaged(u8){};
    // defer buffer.deinit(gpa.allocator());
    // var writer = buffer.writer(gpa.allocator());
    //
    // _ = try std.json.stringify(msg, .{ .emit_null_optional_fields = false }, writer);
    //
    // const stdout = std.io.getStdOut();

    // var bw = std.io.bufferedWriter(stdout.writer());
    // _ = try bw.writer().writeAll(buffer.items);
    // try bw.flush();
    // try conn.receiver.try_push(Message{ .msg = "test!!" });

    // _ = try conn.receiver.try_pop(false);
    // try conn.sender.try_push(Message{ .msg = "test!!" });

}
