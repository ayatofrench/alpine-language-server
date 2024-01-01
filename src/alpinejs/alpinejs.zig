const std = @import("std");
const lsp = @import("lsp_server").lsp;
const ts = @import("../TreeSitter.zig");
const DocumentStore = @import("../DocumentStore.zig").DocumentStore;

pub const AlpineCompletion = struct {
    name: []const u8,
    description: []const u8,
};

pub fn alpineCompletion(
    allocator: std.mem.Allocator,
    text_params: lsp.CompletionParams,
    store: *DocumentStore,
) !?[]const AlpineCompletion {
    const result = try ts.getPositionFromLspCompletion(
        allocator,
        text_params,
        store,
    ) orelse return null;

    return switch (result) {
        .AttributeName => |name| {
            defer allocator.free(name);
            return if (std.mem.startsWith(u8, name, "x-"))
                ALPINE_DIRECTIVES
            else
                null;
        },
        .AttributeValue => null,
    };
}

pub fn alpineHover(params: lsp.TextDocumentPositionParams) ?AlpineCompletion {
    _ = params;
}

const ALPINE_DIRECTIVES: []const AlpineCompletion = &[18]AlpineCompletion{
    .{ .name = "x-data", .description = @embedFile("./attributes/x-data.md") },
    .{ .name = "x-init", .description = @embedFile("./attributes/x-init.md") },
    .{ .name = "x-show", .description = @embedFile("./attributes/x-show.md") },
    .{ .name = "x-bind", .description = @embedFile("./attributes/x-bind.md") },
    .{ .name = "x-on", .description = @embedFile("./attributes/x-on.md") },
    .{ .name = "x-text", .description = @embedFile("./attributes/x-text.md") },
    .{ .name = "x-html", .description = @embedFile("./attributes/x-html.md") },
    .{ .name = "x-model", .description = @embedFile("./attributes/x-model.md") },
    .{ .name = "x-modelable", .description = @embedFile("./attributes/x-modelable.md") },
    .{ .name = "x-for", .description = @embedFile("./attributes/x-for.md") },
    .{ .name = "x-transition", .description = @embedFile("./attributes/x-transition.md") },
    .{ .name = "x-effect", .description = @embedFile("./attributes/x-effect.md") },
    .{ .name = "x-ignore", .description = @embedFile("./attributes/x-ignore.md") },
    .{ .name = "x-ref", .description = @embedFile("./attributes/x-ref.md") },
    .{ .name = "x-cloak", .description = @embedFile("./attributes/x-cloak.md") },
    .{ .name = "x-teleport", .description = @embedFile("./attributes/x-teleport.md") },
    .{ .name = "x-if", .description = @embedFile("./attributes/x-if.md") },
    .{ .name = "x-id", .description = @embedFile("./attributes/x-id.md") },
};
