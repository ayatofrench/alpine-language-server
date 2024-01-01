const std = @import("std");
const lsp = @import("lsp_server").lsp;

pub const DocumentStore = @This();

store: std.hash_map.StringHashMap([]u8),
impl: struct {
    allocator: std.mem.Allocator,
    lock: std.Thread.Mutex = .{},
},

pub fn init(allocator: std.mem.Allocator) DocumentStore {
    const store = std.hash_map.StringHashMap([]u8).init(allocator);

    return .{
        .store = store,
        .impl = .{
            .allocator = allocator,
        },
    };
}

pub fn setDocumentText(self: *DocumentStore, uri: lsp.DocumentUri, document: []const u8) !void {
    const uri_copy = try self.impl.allocator.dupe(u8, uri);
    errdefer self.impl.allocator.free(uri_copy);

    const document_copy = try self.impl.allocator.dupe(u8, document);
    errdefer self.impl.allocator.free(document_copy);

    {
        self.impl.lock.lock();
        defer self.impl.lock.unlock();

        try self.store.put(uri_copy, document_copy);
    }
}

pub fn getDocumentText(self: *DocumentStore, uri: lsp.DocumentUri) ?[]const u8 {
    return self.store.get(uri);
}
