const std = @import("std");
const Connection = @import("lib/lsp_server/Connection.zig").Connection;
const Message = @import("lib/lsp_server/Message.zig").Message;
const types = @import("lib/lsp_server/lsp_types.zig");
const util = @import("lib/lsp_server/util.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    var connection = try Connection.create(alloc, .stdio);

    const params = try connection.init(types.ServerCapabilities{
        .definitionProvider = .{
            .bool = true,
        },
        .hoverProvider = .{
            .bool = true,
        },
        .completionProvider = .{
            .triggerCharacters = &[_][]const u8{ "-", "\"", " " },
            .resolveProvider = false,
        },
    });
    _ = params;

    defer {
        connection.deinit();
        alloc.destroy(connection);
        arena.deinit();
    }

    const RequestMethods = std.meta.Tag(Message.Request.Params);

    while (try connection.receiver.try_pop(true)) |message| {
        std.debug.print("in main loop: {any}\n", .{message});
        defer message.deinit();
        switch (std.meta.stringToEnum(RequestMethods, message.value.request.method).?) {
            .shutdown => {
                if (try connection.handleShutdown(message.value.request.id)) {
                    break;
                }
            },
            .@"textDocument/completion" => {
                // TODO: start off simple. import treesitter and parse the html tree offer completion for alpine attributes
                var items = &[_]types.CompletionItem{
                    types.CompletionItem{
                        .label = "x-data",
                        .kind = types.CompletionItemKind.Text,
                    },
                    types.CompletionItem{
                        .label = "x-show",
                        .kind = types.CompletionItemKind.Text,
                    },
                };

                var completion_reponse = types.CompletionList{
                    .items = items,
                    .isIncomplete = false,
                };

                var payload = try util.toJsonValue(arena.allocator(), completion_reponse);
                try connection.sender.try_push(Message{ .response = .{
                    .id = types.RequestId{
                        .integer = message.value.request.id.integer,
                    },
                    .result = payload,
                    .@"error" = null,
                } });
            },
            .@"textDocument/hover" => {
                // TODO: need to create a hover provider handler here. Then we need to serve markdown files for the
                // alpine attribute definitions
                var hover_response = types.Hover{
                    .contents = .{ .MarkedString = types.MarkedString{ .string = "test" } },
                    .range = null,
                };
                var str = try util.toJsonValue(arena.allocator(), hover_response);
                try connection.sender.try_push(Message{ .response = .{
                    .id = types.RequestId{
                        .integer = message.value.request.id.integer,
                    },
                    .result = str,
                    .@"error" = null,
                } });
            },
            else => {
                std.debug.print("command not supported", .{});
                // connection.setStatus(.exiting_success);
                // break;
            },
        }
    }

    std.debug.print("exit success!", .{});
    std.process.exit(0);
}
