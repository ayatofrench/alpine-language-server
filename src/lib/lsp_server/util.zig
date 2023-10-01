const std = @import("std");
const Value = std.json.Value;
const Message = @import("./Message.zig").Message;

pub fn toJsonValue(allocator: std.mem.Allocator, value: anytype) std.mem.Allocator.Error!std.json.Value {
    const T = @TypeOf(value);

    if (T == Value) {
        std.debug.print("toJsonValue {any}", .{value});
        return value;
    }

    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => Value{ .integer = @as(i64, @intCast(value)) },
        .Float, .ComptimeFloat => Value{ .float = @as(f64, @floatCast(value)) },
        .Bool => Value{ .bool = value },
        .Null => .null,
        .Optional => {
            // TODO: see if there is a better way to do this.
            return blk: {
                if (value) |payload| {
                    break :blk try toJsonValue(allocator, payload);
                } else {
                    break :blk try toJsonValue(allocator, null);
                }
            };
        },
        .Enum, .EnumLiteral => {
            if (comptime std.meta.trait.hasFn("toJsonValue")(T)) {
                return value.toJsonValue();
            }

            return .{ .string = @tagName(value) };
        },
        .Union => |u| {
            if (comptime std.meta.trait.hasFn("toJsonValue")(T)) {
                return value.toJsonValue();
            }

            if (u.tag_type) |UnionTagType| {
                inline for (u.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        return try toJsonValue(allocator, @field(value, u_field.name));
                    }
                }
            }

            // If we don't have a tag type just return the tag name
            return Value{ .string = @tagName(value) };
        },
        .Struct => |s| blk: {
            var obj = std.json.ObjectMap.init(allocator);
            inline for (s.fields) |f| {
                var emit_field = true;

                if (@typeInfo(f.type) == .Optional) {
                    if (@field(value, f.name) == null) {
                        emit_field = false;
                    }
                }
                if (emit_field) {
                    try obj.put(f.name, try toJsonValue(allocator, @field(value, f.name)));
                }
            }
            break :blk Value{ .object = obj };
        },
        .ErrorSet => .{ .string = @errorName(value) },
        // .Pointer => .null,
        // TODO: figure out what to do with pointers...
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .Array => {
                    const Slice = []const std.meta.Elem(ptr_info.child);

                    return try toJsonValue(allocator, @as(Slice, value));
                },
                else => {
                    return try toJsonValue(allocator, value.*);
                },
            },
            .Many, .Slice => {
                if (ptr_info.size == .Many and ptr_info.sentinel == null) {
                    @compileLog(ptr_info, @TypeOf(value));
                    @compileError("Unable to transform type '" ++ @typeName(T) ++ "' to json Value");
                }

                const slice = if (ptr_info.size == .Many) std.mem.span(value) else value;

                if (ptr_info.child == u8) {
                    if (std.unicode.utf8ValidateSlice(slice)) {
                        return Value{ .string = slice };
                    }
                }

                return try toJsonValue(allocator, slice);
            },
            else => @compileError("Unable to transform type '" ++ @typeName(T) ++ "' to json Value"),
        },
        .Array => {
            var list = try std.json.Array.initCapacity(allocator, value.len);
            errdefer list.deinit();

            inline for (value) |inner| {
                try list.append(try toJsonValue(allocator, inner));
            }

            return Value{ .array = list };
        },
        .Vector => |info| {
            const array: [info.len]info.child = value;

            return try toJsonValue(allocator, array);
        },
        .Void => Value{ .object = std.json.ObjectMap.init(allocator) },
        else => @compileError("Unable to transform type '" ++ @typeName(T) ++ "' to json Value"),
    };
}

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const json = "{\"id\": \"123\", \"method\": \"method\", \"params\": {}}";
    // const json = '{"id": "hello", "method": "method", "params": {}}';
    // _ = json;
    const jsonMsg = try std.json.parseFromSlice(Message, arena.allocator(), json, .{
        .ignore_unknown_fields = true,
        .max_value_len = null,
    });
    _ = jsonMsg;
    const Y = struct {
        a: u8,
    };
    const Tag = enum { a, b };
    const TaggedUnion = union(Tag) {
        a: u8,
        b: Y,
    };
    const Z = enum(i32) {
        a = 1,
        b = 2,

        pub usingnamespace EnumStringifyAsInt(@This());
    };
    const X = struct {
        a: u8,
        b: bool,
        c: Y,
        d: ?f64,
        e: Z,
        f: TaggedUnion,
        g: [1]Y,
        h: @Vector(4, i32),
        i: Value,
        j: []const u8,
    };

    const part_one = [1]Y{Y{ .a = 8 }};
    const a = @Vector(4, i32){ 1, 2, 3, 4 };
    const s = X{
        .a = 42,
        .b = true,
        .c = .{ .a = 123 },
        .d = null,
        .e = .a,
        .f = TaggedUnion{
            .b = .{ .a = 1 },
        },
        .g = part_one,
        .h = a,
        .i = Value{ .string = "heh" },
        .j = "heh",
    };

    const val = try toJsonValue(arena.allocator(), s);
    // TODO figure out how to deinit a json.Value
    // defer val.deinit();
    try std.json.stringify(val, .{}, std.io.getStdOut().writer());
    std.debug.print("\n", .{});

    try std.testing.expect(true);
}

pub fn EnumStringifyAsInt(comptime T: type) type {
    return struct {
        pub fn jsonStringify(self: T, stream: anytype) @TypeOf(stream.*).Error!void {
            try stream.write(@intFromEnum(self));
        }
        // pub fn toJsonValue(self: T) !std.json.Value {
        //     return std.json.Value{ .integer = @intFromEnum(self) };
        // }
    };
}
