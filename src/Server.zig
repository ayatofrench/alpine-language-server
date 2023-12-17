const std = @import("std");
const Connection = @import("lsp_server").Connection;
const Message = @import("lsp_server").Message;
const lsp = @import("lsp_server").lsp;
const util = @import("lsp_server").Json;
const alpine = @import("alpinejs/alpinejs.zig");

pub const Server = @This();

connection: *Connection,
allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,

pub fn create(allocator: std.mem.Allocator) !*Server {
    var server = try allocator.create(Server);
    errdefer allocator.destroy(server);

    server.* = Server{
        .connection = try Connection.create(allocator, .stdio),
        .allocator = allocator,
        .arena = undefined,
    };

    return server;
}

pub fn start(self: *Server) !void {
    self.arena = std.heap.ArenaAllocator.init(self.allocator);
    defer {
        self.connection.deinit();
        self.allocator.destroy(self.connection);
        self.arena.deinit();
    }

    const params = try self.connection.init(lsp.ServerCapabilities{
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

    try self.main_loop();
}

fn main_loop(self: *Server) !void {
    while (try self.connection.receiver.try_pop(true)) |message| {
        std.debug.print("in main loop: {any}\n", .{message});
        defer message.deinit();

        switch (message.value.tag) {
            .request => try self.handleRequest(message),
            .notification => {},
            else => {},
        }
    }
}

// fn toCompletionList(items: []const alpine.AlpineCompletion) lsp.CompletionList {
//     var completionItems: [2]lsp.CompletionItem = undefined;
//     for (items, 0..) |item, i| {
//         completionItems[i] = lsp.CompletionItem{
//             .label = item.name,
//             .detail = item.description,
//         };
//     }
//
//     const new_memory = self.
//
//     return lsp.CompletionList{
//         .items = completionItems,
//         .isIncomplete = false,
//     };
// }

fn handleRequest(self: *Server, message: std.json.Parsed(Message)) !void {
    const RequestMethods = std.meta.Tag(Message.Request.Params);
    switch (std.meta.stringToEnum(RequestMethods, @tagName(message.value.request.?.params)).?) {
        .shutdown => {
            if (try self.connection.handleShutdown(message.value.request.?.id)) {
                // break;
            }
        },
        .@"textDocument/completion" => {
            // TODO: start off simple. import treesitter and parse the html tree offer completion for alpine attributes
            // var items = alpine.alpineCompletion();
            // var completion_reponse = toCompletionList(items);

            // TODO: Think about how to handle memory here
            var items = alpine.alpineCompletion();
            var completionItems: [2]lsp.CompletionItem = undefined;
            for (items, 0..) |item, i| {
                completionItems[i] = lsp.CompletionItem{
                    .label = item.name,
                    .detail = item.description,
                };
            }

            var completion_reponse = lsp.CompletionList{
                .items = &completionItems,
                .isIncomplete = false,
            };
            var payload = try util.toJsonValue(self.arena.allocator(), completion_reponse);
            try self.connection.sender.try_push(Message{
                .tag = .response,
                .response = .{
                    .id = lsp.RequestId{
                        .integer = message.value.request.?.id.integer,
                    },
                    .result = payload,
                    .@"error" = null,
                },
            });
        },
        .@"textDocument/hover" => {
            // TODO: need to create a hover provider handler here. Then we need to serve markdown files for the
            // alpine attribute definitions
            var hover_response = lsp.Hover{
                .contents = .{ .MarkedString = lsp.MarkedString{ .string = "test" } },
                .range = null,
            };
            var str = try util.toJsonValue(self.arena.allocator(), hover_response);
            try self.connection.sender.try_push(Message{
                .tag = .response,
                .response = .{
                    .id = lsp.RequestId{
                        .integer = message.value.request.?.id.integer,
                    },
                    .result = str,
                    .@"error" = null,
                },
            });
        },
        else => {
            std.debug.print("command not supported", .{});
            // self.connection.setStatus(.exiting_success);
            // break;
        },
    }
}
