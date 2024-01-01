const std = @import("std");
const Connection = @import("lsp_server").Connection;
const DocumentStore = @import("DocumentStore.zig");
const Message = @import("lsp_server").Message;
const lsp = @import("lsp_server").lsp;
const util = @import("lsp_server").Json;
const alpine = @import("alpinejs/alpinejs.zig");

pub const Server = @This();

const CompletionItems = std.ArrayList(lsp.CompletionItem);

const RequestResult = union(enum) {
    shutdown,
    result: Message,
};

connection: *Connection,
document_store: DocumentStore,
allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,

pub fn create(allocator: std.mem.Allocator) !*Server {
    const server = try allocator.create(Server);
    errdefer allocator.destroy(server);

    server.* = Server{
        .connection = try Connection.create(allocator, .stdio),
        .document_store = DocumentStore.init(allocator),
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

    _ = try self.connection.init(lsp.ServerCapabilities{
        .textDocumentSync = .{
            .TextDocumentSyncOptions = .{
                .openClose = true,
                .change = .Full,
                .save = .{ .bool = true },
                .willSave = true,
                .willSaveWaitUntil = true,
            },
        },
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

    try self.main_loop();
}

fn handleRequest(self: *Server, message: std.json.Parsed(Message)) !?RequestResult {
    return switch (message.value.request.?.params) {
        .shutdown => {
            if (try self.connection.handleShutdown(message.value.request.?.id)) {
                return .shutdown;
            }

            return .shutdown;
        },
        .@"textDocument/completion" => |params| {
            // TODO: Think about how to handle memory here
            const items = try alpine.alpineCompletion(
                self.allocator,
                params,
                &self.document_store,
            );

            var completionItems = CompletionItems.init(self.allocator);
            if (items) |compItems| {
                for (compItems) |item| {
                    try completionItems.append(.{
                        .label = item.name,
                        .detail = item.description,
                    });
                }
            }

            const completion_reponse = lsp.CompletionList{
                .items = completionItems.items,
                .isIncomplete = false,
            };
            const payload = try util.toJsonValue(self.arena.allocator(), completion_reponse);
            return RequestResult{ .result = Message{
                .tag = .response,
                .response = .{
                    .id = lsp.RequestId{
                        .integer = message.value.request.?.id.integer,
                    },
                    .result = payload,
                    .@"error" = null,
                },
            } };
        },
        .@"textDocument/hover" => {
            // TODO: need to create a hover provider handler here. Then we need to serve markdown files for the
            // alpine attribute definitions
            const hover_response = lsp.Hover{
                .contents = .{ .MarkedString = lsp.MarkedString{ .string = "test" } },
                .range = null,
            };
            const str = try util.toJsonValue(self.arena.allocator(), hover_response);
            return RequestResult{ .result = Message{
                .tag = .response,
                .response = .{
                    .id = lsp.RequestId{
                        .integer = message.value.request.?.id.integer,
                    },
                    .result = str,
                    .@"error" = null,
                },
            } };
        },
        else => {
            std.log.info("command not supported\n", .{});
            return null;
        },
    };
}

fn handleNotification(self: *Server, message: std.json.Parsed(Message)) !void {
    switch (message.value.notification.?) {
        .@"textDocument/didOpen" => |noti| {
            try self.document_store.setDocumentText(noti.textDocument.uri, noti.textDocument.text);
        },
        .@"textDocument/didChange" => |noti| {
            const uri = noti.textDocument.uri;
            const text = noti.contentChanges[0].literal_1.text;

            try self.document_store.setDocumentText(uri, text);
        },
        else => {
            std.log.info("notification not supported\n", .{});
        },
    }
}

fn main_loop(self: *Server) !void {
    while (try self.connection.receiver.try_pop(true)) |message| {
        defer message.deinit();

        switch (message.value.tag) {
            .request => {
                const result = try self.handleRequest(message) orelse continue;

                switch (result) {
                    .shutdown => break,
                    .result => |msg| {
                        try self.connection.sender.try_push(msg);
                    },
                }
            },
            .notification => try self.handleNotification(message),
            else => {},
        }
    }
}
