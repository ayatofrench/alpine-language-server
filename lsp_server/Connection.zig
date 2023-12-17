pub const Connection = @This();

const std = @import("std");
const Channel = @import("Channel.zig").Channel;
const Header = @import("Header.zig");
const Message = @import("Message.zig").Message;
const types = @import("lsp_types.zig");
const util = @import("util.zig");

// pub const Message = struct {
//     msg: []const u8,
// };

// pub const MessageVariant = union(enum) {
//
// }

const ReceiverChannel = Channel(std.json.Parsed(Message));
const SenderChannel = Channel(Message);

allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
sender: *SenderChannel,
receiver: *ReceiverChannel,
io_threads: IoThreads,
status: Status = .uninitialized,
in_lock: std.Thread.Mutex = .{},
out_lock: std.Thread.Mutex = .{},
_message_store: std.ArrayList(std.json.Parsed(Message)),

pub const ConnectionType = enum {
    stdio,
};

pub const Status = enum {
    /// the server has not received a `initialize` request
    uninitialized,
    /// the server has received a `initialize` request and is awaiting the `initialized` notification
    initializing,
    /// the server has been initialized and is ready to received requests
    initialized,
    /// the server has been shutdown and can't handle any more requests
    shutdown,
    /// the server is received a `exit` notification and has been shutdown
    exiting_success,
    /// the server is received a `exit` notification but has not been shutdown
    exiting_failure,
};

pub const IoThreads = struct {
    writer: std.Thread,
    reader: std.Thread,

    const SelfIoThreads = @This();

    pub fn join(self: SelfIoThreads) void {
        self.writer.join();
        self.reader.join();
    }
};

pub fn create(allocator: std.mem.Allocator, conn_type: ConnectionType) !*Connection {
    const c = try allocator.create(Connection);
    errdefer allocator.destroy(c);

    c.* = switch (conn_type) {
        .stdio => try stdioImpl(allocator),
    };

    var writer = std.Thread.spawn(.{}, writer_sender, .{c}) catch unreachable;
    errdefer writer.join();

    var reader = std.Thread.spawn(.{}, reader_receiver, .{c}) catch unreachable;
    errdefer reader.join();

    c.io_threads = IoThreads{
        .writer = writer,
        .reader = reader,
    };
    c._message_store = std.ArrayList(std.json.Parsed(Message)).init(allocator);

    return c;
}

// TODO: Implement init
pub fn init(self: *Connection, server_capabilities: types.ServerCapabilities) !std.json.Parsed(Message) {
    self.arena = std.heap.ArenaAllocator.init(self.allocator);
    errdefer self.arena.deinit();

    const init_msg = try self.initStart();

    const init_data = try util.toJsonValue(self.arena.allocator(), types.InitializeResult{
        .capabilities = server_capabilities,
        .serverInfo = .{ .name = "alpine-lsp", .version = "0.1" },
    });

    // TODO: handle the case when init_msg can be null
    if (init_msg) |msg| {
        try self.initFinish(msg.value.request.?.id, init_data);
    }

    return init_msg.?;
}

pub fn initStart(self: *Connection) !?std.json.Parsed(Message) {
    while (try self.receiver.try_pop(true)) |msg| {
        break switch (msg.value.tag) {
            .request => {
                return msg;
            },
            else => std.debug.panic("we should not be here on startup", .{}),
        };
    }

    return null;
}
pub fn initFinish(self: *Connection, id: types.RequestId, init_result: types.LSPAny) anyerror!void {
    const resp = Message{
        .tag = .response,
        .response = Message.Response{
            .id = id,
            .result = init_result,
            .@"error" = null,
        },
    };
    try self.sender.try_push(resp);

    while (try self.receiver.try_pop(true)) |msg| {
        defer msg.deinit();
        switch (msg.value.tag) {
            .notification => {
                std.debug.print("we received the notification {any}\n", .{msg.value});
                return;
            },
            // TODO: Have a proper lsp error set
            else => {
                std.debug.print("are we error?", .{});
                return error.ProtocolError;
            },
        }
    }
}
pub fn handleShutdown(self: *Connection, msg_id: types.RequestId) !bool {
    const shutdown_resp = Message{
        .tag = .response,
        .response = .{
            .id = msg_id,
            .result = .null,
        },
    };

    try self.sender.try_push(shutdown_resp);

    while (try self.receiver.try_pop(true)) |msg| {
        switch (msg.value.tag) {
            .notification => {
                std.debug.print("we received the notification {any}\n", .{msg});
                self.*.status = .exiting_success;
                return true;
            },
            // TODO: Have a proper lsp error set
            else => {
                std.debug.print("are we error?", .{});
                return error.ProtocolError;
            },
        }
    }

    return false;
}

pub fn deinit(self: *Connection) void {
    self.io_threads.join();
    self.receiver.deinit();
    self.sender.deinit();
    self.arena.deinit();
}

pub fn running(self: Connection) bool {
    switch (self.status) {
        .exiting_success, .exiting_failure => return false,
        else => return true,
    }
}

pub fn setStatus(self: *Connection, newStatus: Status) void {
    self.*.status = newStatus;
}

fn writer_sender(c: *Connection) !void {
    const stdout = std.io.getStdOut();
    var out_writer = stdout.writer();

    // TODO: should there be another way to have more controller over
    // flushing the buffer? Need to explore more options here.
    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(c.allocator);
    var writer = buffer.writer(c.allocator);

    //     const JsonRpc = struct {
    //
    //         msg: types.LspAny,
    // };

    // while (c.running() or c.sender.fifo.count > 0) {
    while (try c.sender.try_pop(true)) |msg| {
        try writer.writeAll(
            \\{"jsonrpc": "2.0"
        );
        try writer.writeAll(
            \\,"id":
        );
        _ = try std.json.stringify(msg.response.?.id, .{ .emit_null_optional_fields = false }, writer);
        try writer.writeAll(
            \\,"result":
        );
        _ = try std.json.stringify(msg.response.?.result, .{ .emit_null_optional_fields = false }, writer);
        try writer.writeByte('}');

        var header_buffer: [64]u8 = undefined;
        const prefix = std.fmt.bufPrint(&header_buffer, "Content-Length: {d}\r\n\r\n", .{buffer.items.len}) catch unreachable;

        try out_writer.writeAll(prefix);
        try out_writer.writeAll(buffer.items);

        std.debug.print("{s}\n", .{buffer.items});

        buffer.clearAndFree(c.allocator);
        // TODO: we need to gc the messages here will figure that out later.
        // Just need to make sure that I right and the message doesn't seg fault
        // while (c._message_store.items) |i| {
        //     _ = i;
        //
        // }

        if (!c.running()) break;
    }
    std.debug.print("ending...", .{});
}

fn reader_receiver(c: *Connection) !void {
    const stdin = std.io.getStdIn();
    var reader = std.io.bufferedReader(stdin.reader());

    while (c.running()) {
        const lsp_msg = try Message.read(c.allocator, reader.reader());

        std.debug.print("Client msg: {any}\n", .{lsp_msg});
        // {
        //     c.out_lock.lock();
        //     defer c.out_lock.unlock();
        //
        //     try c._message_store.append(lsp_msg);
        // }

        try c.receiver.try_push(lsp_msg);
    }
}

fn stdioImpl(allocator: std.mem.Allocator) !Connection {
    var sender = try allocator.create(SenderChannel);
    var receiver = try allocator.create(ReceiverChannel);
    errdefer allocator.destroy(sender);
    errdefer allocator.destroy(receiver);

    sender.init(allocator);
    receiver.init(allocator);

    return Connection{
        .allocator = allocator,
        .sender = sender,
        .receiver = receiver,
        .io_threads = undefined,
        .arena = undefined,
        ._message_store = undefined,
    };
}

// fn stdio_transport(allocator: std.mem.Allocator) !*Connection {
//     const c = try allocator.create(Connection);
//     errdefer allocator.destroy(c);
//
//     var sender = try allocator.create(MsgChannel);
//     var receiver = try allocator.create(MsgChannel);
//     sender.init(allocator);
//     receiver.init(allocator);
//
//     c.* = Connection{
//         .allocator = allocator,
//         .sender = sender,
//         .receiver = receiver,
//         .io_threads = undefined,
//     };
//
//     var writer = std.Thread.spawn(.{}, writer_worker, .{ c, sender }) catch unreachable;
//
//     c.io_threads = IoThreads{
//         .writer = &writer,
//     };
//
//     return c;
// }
//
// Content-Length: 49\r\nContent-Type: application/vscode-jsonrpc; charset=utf8\r\n\r\n{"id": "hello", "method": "method", "params": {}}
