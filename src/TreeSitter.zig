const std = @import("std");
const treez = @import("treez");
const lsp = @import("lsp_server").lsp;
const querier = @import("TSQuerier.zig");
const DocumentStore = @import("DocumentStore.zig");

pub const Position = union(enum) {
    AttributeName: []u8,
    AttributeValue: struct {
        name: []u8,
        value: []u8,
    },
};

pub const TSLanguage = enum {
    astro,
    html,
};

fn findElementReferentToCurrentNode(node: treez.Node) ?treez.Node {
    if (std.mem.eql(u8, node.getType(), "element") or std.mem.eql(u8, node.getType(), "fragment")) {
        return node;
    }

    const parent = node.getParent();
    return if (parent.isNull())
        null
    else
        findElementReferentToCurrentNode(parent);
}

fn queryPosition(
    allocator: std.mem.Allocator,
    file_ext: []const u8,
    root: treez.Node,
    source: []const u8,
    trigger_point: treez.Point,
) ?Position {
    const closest_node = root.getDescendentForPointRange(trigger_point, trigger_point);
    if (closest_node.isNull()) return null;

    const element = findElementReferentToCurrentNode(closest_node) orelse return null;

    const attr_completion = querier.queryAttrKeysForCompletion(allocator, file_ext, element, source, trigger_point);

    return attr_completion;
}

pub fn getPositionFromLspCompletion(
    allocator: std.mem.Allocator,
    text_params: lsp.CompletionParams,
    store: *DocumentStore,
) !?Position {
    var uri_tokens = std.mem.splitBackwards(u8, text_params.textDocument.uri, ".");
    const file_ext = uri_tokens.first();
    var text = store.getDocumentText(text_params.textDocument.uri) orelse return null;
    text = try allocator.dupe(u8, text);
    defer allocator.free(text);

    const pos = text_params.position;

    const lang = switch (std.meta.stringToEnum(TSLanguage, file_ext).?) {
        .astro => try treez.Language.get("astro"),
        .html => try treez.Language.get("html"),
    };

    const parser = try treez.Parser.create();
    defer parser.destroy();

    try parser.setLanguage(lang);
    // parser.useStandardLogger();

    const tree = try parser.parseString(null, text);
    const root_node = tree.getRootNode();
    const trigger_point = treez.Point{
        .row = pos.line,
        .column = pos.character,
    };

    return queryPosition(allocator, file_ext, root_node, text, trigger_point);
}
