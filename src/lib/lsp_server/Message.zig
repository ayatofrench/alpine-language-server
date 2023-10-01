const std = @import("std");
const types = @import("../../lsp_types.zig");
const Header = @import("Header.zig");

// Credit: https://github.com/zigtools/zls/blob/master/src/Server.zig
pub const Message = union(enum) {
    request: Request,
    notification: Notification,
    response: Response,

    pub const Request = struct {
        id: types.RequestId,
        method: []const u8,
        params: Params,

        pub const Params = union(enum) {
            initialize: types.InitializeParams,
            shutdown: void,
            @"textDocument/willSaveWaitUntil": types.WillSaveTextDocumentParams,
            @"textDocument/semanticTokens/full": types.SemanticTokensParams,
            @"textDocument/semanticTokens/range": types.SemanticTokensRangeParams,
            @"textDocument/inlayHint": types.InlayHintParams,
            @"textDocument/completion": types.CompletionParams,
            @"textDocument/signatureHelp": types.SignatureHelpParams,
            @"textDocument/definition": types.DefinitionParams,
            @"textDocument/typeDefinition": types.TypeDefinitionParams,
            @"textDocument/implementation": types.ImplementationParams,
            @"textDocument/declaration": types.DeclarationParams,
            @"textDocument/hover": types.HoverParams,
            @"textDocument/documentSymbol": types.DocumentSymbolParams,
            @"textDocument/formatting": types.DocumentFormattingParams,
            @"textDocument/rename": types.RenameParams,
            @"textDocument/references": types.ReferenceParams,
            @"textDocument/documentHighlight": types.DocumentHighlightParams,
            @"textDocument/codeAction": types.CodeActionParams,
            @"textDocument/foldingRange": types.FoldingRangeParams,
            @"textDocument/selectionRange": types.SelectionRangeParams,
            unknown: []const u8,
        };
    };

    pub const Notification = union(enum) {
        initialized: types.InitializedParams,
        exit: void,
        @"$/cancelRequest": types.CancelParams,
        @"$/setTrace": types.SetTraceParams,
        @"textDocument/didOpen": types.DidOpenTextDocumentParams,
        @"textDocument/didChange": types.DidChangeTextDocumentParams,
        @"textDocument/didSave": types.DidSaveTextDocumentParams,
        @"textDocument/didClose": types.DidCloseTextDocumentParams,
        @"workspace/didChangeWorkspaceFolders": types.DidChangeWorkspaceFoldersParams,
        @"workspace/didChangeConfiguration": types.DidChangeConfigurationParams,
        unknown: []const u8,
    };

    pub const Response = struct {
        id: types.RequestId,
        result: ?types.LSPAny = null,
        @"error": ?types.ResponseError = null,

        // pub const Data = union(enum) {
        // };
    };

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Message {
        // const tracy_zone = tracy.trace(@src());
        // defer tracy_zone.end();
        const json_value = try std.json.parseFromTokenSourceLeaky(std.json.Value, allocator, source, options);
        return try jsonParseFromValue(allocator, json_value, options);
    }

    pub fn jsonParseFromValue(
        allocator: std.mem.Allocator,
        source: std.json.Value,
        options: std.json.ParseOptions,
    ) !Message {
        // const tracy_zone = tracy.trace(@src());
        // defer tracy_zone.end();

        if (source != .object) return error.UnexpectedToken;
        const object = source.object;

        @setEvalBranchQuota(10_000);
        if (object.get("id")) |id_obj| {
            const msg_id = try std.json.parseFromValueLeaky(types.RequestId, allocator, id_obj, options);

            if (object.get("method")) |method_obj| {
                const msg_method = try std.json.parseFromValueLeaky([]const u8, allocator, method_obj, options);

                const msg_params = object.get("params") orelse .null;

                const fields = @typeInfo(Request.Params).Union.fields;

                inline for (fields) |field| {
                    if (std.mem.eql(u8, msg_method, field.name)) {
                        const params = if (field.type == void)
                            void{}
                        else
                            try std.json.parseFromValueLeaky(field.type, allocator, msg_params, options);

                        return .{ .request = .{
                            .id = msg_id,
                            .method = field.name,
                            .params = @unionInit(Request.Params, field.name, params),
                        } };
                    }
                }
                return .{ .request = .{
                    .id = msg_id,
                    .method = msg_method,
                    .params = .{ .unknown = msg_method },
                } };
            } else {
                const result = object.get("result") orelse .null;
                const error_obj = object.get("error") orelse .null;

                const err = try std.json.parseFromValueLeaky(?types.ResponseError, allocator, error_obj, options);

                if (result != .null and err != null) return error.UnexpectedToken;

                if (err) |e| {
                    return .{ .response = .{
                        .id = msg_id,

                        .@"error" = e,
                    } };
                } else {
                    return .{ .response = .{
                        .id = msg_id,
                        .result = result,
                    } };
                }
            }
        } else {
            const method_obj = object.get("method") orelse return error.UnexpectedToken;
            const msg_method = try std.json.parseFromValueLeaky([]const u8, allocator, method_obj, options);

            const msg_params = object.get("params") orelse .null;

            const fields = @typeInfo(Notification).Union.fields;

            inline for (fields) |field| {
                if (std.mem.eql(u8, msg_method, field.name)) {
                    const params = if (field.type == void)
                        void{}
                    else
                        try std.json.parseFromValueLeaky(field.type, allocator, msg_params, options);

                    return .{
                        .notification = @unionInit(Notification, field.name, params),
                    };
                }
            }
            return .{ .notification = .{ .unknown = msg_method } };
        }
    }

    pub fn isBlocking(self: Message) bool {
        switch (self) {
            .request => |request| switch (request.params) {
                .initialize,
                .shutdown,
                => return true,
                .@"textDocument/willSaveWaitUntil",
                .@"textDocument/semanticTokens/full",
                .@"textDocument/semanticTokens/range",
                .@"textDocument/inlayHint",
                .@"textDocument/completion",
                .@"textDocument/signatureHelp",
                .@"textDocument/definition",
                .@"textDocument/typeDefinition",
                .@"textDocument/implementation",
                .@"textDocument/declaration",
                .@"textDocument/hover",
                .@"textDocument/documentSymbol",
                .@"textDocument/formatting",
                .@"textDocument/rename",
                .@"textDocument/references",
                .@"textDocument/documentHighlight",
                .@"textDocument/codeAction",
                .@"textDocument/foldingRange",
                .@"textDocument/selectionRange",
                => return false,
                .unknown => return false,
            },
            .notification => |notification| switch (notification) {
                .@"$/cancelRequest" => return false,
                .initialized,
                .exit,
                .@"$/setTrace",
                .@"textDocument/didOpen",
                .@"textDocument/didChange",
                .@"textDocument/didSave",
                .@"textDocument/didClose",
                .@"workspace/didChangeWorkspaceFolders",
                .@"workspace/didChangeConfiguration",
                => return true,
                .unknown => return false,
            },
            .response => return true,
        }
    }

    pub fn format(message: Message, comptime fmt_str: []const u8, options: std.fmt.FormatOptions, writer: anytype) @TypeOf(writer).Error!void {
        _ = options;
        if (fmt_str.len != 0) std.fmt.invalidFmtError(fmt_str, message);
        switch (message) {
            .request => |request| try writer.print("request-{}-{s}", .{ request.id, switch (request.params) {
                .unknown => |method| method,
                else => @tagName(request.params),
            } }),
            .notification => |notification| try writer.print("notification-{s}", .{switch (notification) {
                .unknown => |method| method,
                else => @tagName(notification),
            }}),
            .response => |response| try writer.print("response-{}", .{response.id}),
        }
    }

    pub fn read(allocator: std.mem.Allocator, reader: anytype) !Message {
        std.debug.print("reading stdin...\n", .{});
        std.debug.print("will this print?...\n", .{});
        const header = Header.parse(allocator, reader) catch {
            std.debug.print("there was an error...\n", .{});
            unreachable;
        };
        defer header.deinit(allocator);

        const content = try allocator.alloc(u8, header.content_length);
        defer allocator.free(content);

        try reader.readNoEof(content);

        const lsp_msg = try std.json.parseFromSlice(Message, allocator, content, .{
            .ignore_unknown_fields = true,
            .max_value_len = null,
        });

        return lsp_msg.value;
    }

    pub fn write(writer: anytype) !void {
        _ = writer;
    }
};