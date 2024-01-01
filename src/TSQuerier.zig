const std = @import("std");
const treez = @import("treez");
const lsp = @import("lsp_server").lsp;
const Position = @import("TreeSitter.zig").Position;
const TSLanguage = @import("TreeSitter.zig").TSLanguage;

const CaptureDetails = struct {
    value: []const u8,
    end_position: *treez.Point,
};

pub const CaptureDetailsMap = std.hash_map.StringHashMap(CaptureDetails);

pub fn query_props(
    allocator: std.mem.Allocator,
    file_ext: []const u8,
    query_string: []const u8,
    node: treez.Node,
    source: []const u8,
    trigger_point: treez.Point,
) !CaptureDetailsMap {
    const lang = switch (std.meta.stringToEnum(TSLanguage, file_ext).?) {
        .astro => try treez.Language.get("astro"),
        .html => try treez.Language.get("html"),
    };

    const parser = try treez.Parser.create();
    defer parser.destroy();

    try parser.setLanguage(lang);

    const tree = try parser.parseString(null, source);
    defer tree.destroy();

    const query = try treez.Query.create(lang, query_string);
    defer query.destroy();

    var pv = try treez.CursorWithValidation.init(allocator, query);

    const cursor = try treez.Query.Cursor.create();
    defer cursor.destroy();

    cursor.execute(query, node);

    var capture_details = CaptureDetailsMap.init(allocator);

    while (pv.nextMatch(source, cursor)) |match| {
        for (match.captures()) |cap| {
            const cap_start_point = cap.node.getStartPoint();
            if (cap_start_point.row <= trigger_point.row and cap_start_point.column <= trigger_point.column) {
                const capture_name = query.getCaptureNameForId(cap.id);
                const capture_name_copy = try allocator.dupe(u8, capture_name);

                const capture_value = source[cap.node.getStartByte()..cap.node.getEndByte()];
                const capture_value_copy = try allocator.dupe(u8, capture_value);

                const end_point = try allocator.create(treez.Point);
                end_point.* = cap.node.getEndPoint();

                try capture_details.put(capture_name_copy, .{
                    .value = capture_value_copy,
                    .end_position = end_point,
                });
            }
        }
    }

    return capture_details;
}
pub fn queryAttrKeysForCompletion(
    allocator: std.mem.Allocator,
    file_ext: []const u8,
    node: treez.Node,
    source: []const u8,
    trigger_point: treez.Point,
) ?Position {
    const query_string =
        \\(
        \\    [
        \\        (_ 
        \\            (tag_name) 
        \\
        \\                (_)*
        \\
        \\                (attribute (attribute_name) @attr_name) @complete_match
        \\
        \\                (#eq? @attr_name @complete_match)
        \\            )
        \\
        \\            (_ 
        \\              (tag_name) 
        \\
        \\              (attribute (attribute_name)) 
        \\
        \\              (ERROR)
        \\            ) @unfinished_tag
        \\        ]
        \\        (#match? @attr_name "x-.*")
        \\    )
    ;

    const props = query_props(allocator, file_ext, query_string, node, source, trigger_point) catch return null;
    const attr_name = props.get("attr_name");
    // TODO: we probably want to bubble the error here, but this okay for now

    if (attr_name == null) return null;

    return if (props.get("unfinished_tag") != null)
        null
    else {
        const attr_value = allocator.dupe(u8, attr_name.?.value) catch return null;
        return Position{
            .AttributeName = attr_value,
        };
    };
}
