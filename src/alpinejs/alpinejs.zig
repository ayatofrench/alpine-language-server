const std = @import("std");
const lsp = @import("lsp_server").lsp;

pub const AlpineCompletion = struct {
    name: []const u8,
    description: []const u8,
};

pub fn alpineCompletion() []const AlpineCompletion {
    return ALPINE_DIRECTIVES;
}

pub fn alpineHover(params: lsp.TextDocumentPositionParams) ?AlpineCompletion {
    _ = params;
}

const ALPINE_DIRECTIVES: []const AlpineCompletion = &[2]AlpineCompletion{
    .{ .name = "x-data", .description = @embedFile("./attributes/x-data.md") },
    .{ .name = "x-init", .description = @embedFile("./attributes/x-data.md") },
};
