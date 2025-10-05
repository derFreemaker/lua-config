const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");

const IndexCovered = @import("lua_index_covered.zig").IndexCovered;

pub const Ref = @import("lua_ref.zig");
pub const StructMeta = @import("lua_struct_meta.zig");

const Lua = @This();

pub fn dumpStack(lua: *zlua.Lua) void {
    const top = lua.getTop();
    std.debug.print("stack dump: [{}]\n", .{top});
    for (0..@as(usize, @intCast(top))) |i| {
        const index: i32 = @intCast(i + 1);
        std.debug.print("  {}: {s}", .{ i, lua.typeNameIndex(index) });

        const lua_type = lua.typeOf(index);
        switch (lua_type) {
            .none,
            .nil,
            => continue,

            else => {
                std.debug.print(" -> ", .{});
            },
        }

        switch (lua_type) {
            .boolean => {
                std.debug.print("'{}'", .{lua.toBoolean(index)});
            },
            .number => {
                if (lua.toNumber(index)) |value| {
                    std.debug.print("'{}'", .{value});
                } else |_| {
                    std.debug.print("<ERROR NUMBER>", .{});
                }
            },
            .string => {
                if (lua.toString(index)) |value| {
                    std.debug.print("'{s}'", .{value});
                } else |_| {
                    std.debug.print("<ERROR STRING>", .{});
                }
            },
            else => {
                std.debug.print("'{s}'", .{lua.toStringEx(index)});
                lua.pop(1);
            },
        }

        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

pub inline fn getLuaName(comptime T: type) [:0]const u8 {
    comptime {
        return switch (@typeInfo(T)) {
            .int => "integer",
            .float => "number",
            .bool => "boolean",
            .pointer => |p| {
                return std.fmt.comptimePrint("*{s}{s}", .{
                    if (p.is_const) "const " else "",
                    getLuaName(p.child),
                });
            },
            .@"struct" => |s| {
                if (s.is_tuple) {
                    var str = "";
                    for (s.fields, 0..) |field, i| {
                        str = std.fmt.comptimePrint("{s}{s}{s}", .{
                            str,
                            getLuaName(field.type),
                            if (i + 1 < s.fields.len) ", " else "",
                        });
                    }

                    return str;
                }

                const meta = StructMeta.from(T) orelse {
                    return @typeName(T);
                };

                return meta.name orelse @typeName(T);
            },
            .@"union" => {
                const meta = StructMeta.from(T) orelse {
                    return @typeName(T);
                };

                return meta.name orelse @typeName(T);
            },
            else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
        };
    }
}

pub fn luaOOM(lua: *zlua.Lua) i32 {
    _ = lua.pushStringZ("out of memory");
    return 1;
}

pub fn luaErrorOOM(lua: *zlua.Lua) noreturn {
    _ = lua.pushStringZ("out of memory");
    lua.raiseError();
}

fn isStringType(comptime T: type) bool {
    if (@typeInfo(T) != .pointer) {
        return false;
    }

    if (@typeInfo(T).pointer.child != u8) {
        return false;
    }

    if (@typeInfo(T).pointer.size != .slice and
        @typeInfo(T).pointer.size != .many)
    {
        return false;
    }

    return true;
}

fn isArrayType(comptime T: type) bool {
    if (comptime isStringType(T)) {
        return false;
    }

    if (@typeInfo(T) != .pointer) {
        return false;
    }

    const info = @typeInfo(T).pointer;
    return switch (info.size) {
        .many, .slice => true,
        else => false,
    };
}

pub const ThisState = struct {
    lua: *zlua.Lua,

    pub fn init(lua: *zlua.Lua) ThisState {
        return .{
            .lua = lua,
        };
    }
};

pub const Array = struct {
    pub fn is(lua: *zlua.Lua, comptime T: type, index: i32) bool {
        const abs_index = lua.absIndex(index);

        if (lua.typeOf(abs_index) != .table) {
            return false;
        }

        lua.len(abs_index);
        if (!lua.isInteger(-1)) {
            lua.pop(1);
            return false;
        }
        const tbl_len: i64 = lua.toInteger(-1) catch unreachable;
        lua.pop(1);

        const item_len = itemLen(T);
        if (@mod(tbl_len, item_len) != 0) {
            return false;
        }

        const items_count: usize = @intCast(tbl_len / item_len);
        for (0..items_count) |i| {
            for (0..item_len) |j| {
                lua.pushInteger(@intCast(i * item_len + j + 1));
                _ = lua.getTable(abs_index);
            }
            defer lua.pop(item_len);

            if (!Lua.is(lua, T, -item_len).value) {
                return false;
            }
        }

        return true;
    }

    pub fn get(lua: *zlua.Lua, allocator: std.mem.Allocator, comptime T: type, index: i32) !T {
        const abs_index = lua.absIndex(index);

        if (@typeInfo(T) != .pointer or @typeInfo(T).pointer.size != .slice) {
            @compileError("only support slices");
        }
        const ptr_info = @typeInfo(T).pointer;
        const child = ptr_info.child;

        if (lua.typeOf(abs_index) != .table) {
            return error.ExpectedLuaTable;
        }

        var size = lua.lenRaiseErr(abs_index);
        const child_len = Lua.itemLen(child);
        if (child_len > 1) {
            if (@mod(size, child_len) != 0) {
                return error.LuaTableLenghtNotMatching;
            }
            size = size / child_len;
        }

        var arr: []child = undefined;
        if (ptr_info.sentinel()) |sentinel| {
            arr = try allocator.allocSentinel(child, size, sentinel);
        } else {
            arr = try allocator.alloc(child, size);
        }

        for (1..size + 1) |i| {
            inline for (0..child_len) |j| {
                lua.pushInteger(child_len * (i - 1) + j + 1);
                _ = lua.getTable(abs_index);
            }

            const result = try Lua.get(lua, allocator, child, -child_len);
            lua.pop(child_len);

            arr[i - 1] = result.value;
        }

        return arr;
    }

    pub fn check(lua: *zlua.Lua, allocator: std.mem.Allocator, comptime T: type, index: i32) T {
        const abs_index = lua.absIndex(index);

        if (@typeInfo(T) != .pointer or @typeInfo(T).pointer.size != .slice) {
            @compileError("only support slices");
        }
        const ptr_info = @typeInfo(T).pointer;
        const child = ptr_info.child;

        if (lua.typeOf(abs_index) != .table) {
            lua.typeError(index, "table");
        }

        var size = lua.lenRaiseErr(abs_index);
        const child_len = comptime Lua.itemLen(child);
        if (child_len > 1) {
            if (@mod(size, child_len) != 0) {
                lua.argError(index, std.fmt.comptimePrint("array length needs to be a multiple of {}", .{child_len}).*);
            }
            size = size / child_len;
        }

        var arr: []child = undefined;
        if (ptr_info.sentinel()) |sentinel| {
            arr = allocator.allocSentinel(child, size, sentinel) catch luaErrorOOM(lua);
        } else {
            arr = allocator.alloc(child, @intCast(size)) catch luaErrorOOM(lua);
        }

        for (1..@intCast(size + 1)) |i| {
            inline for (0..child_len) |j| {
                lua.pushInteger(@intCast(child_len * (i - 1) + j + 1));
                _ = lua.getTable(abs_index);
            }

            const result = Lua.get(lua, child, -child_len) catch |err| {
                if (err == error.OutOfMemory) {
                    luaErrorOOM(lua);
                }

                lua.argError(index, std.fmt.comptimePrint("array of: {s}", .{getLuaName(child)}));
            };
            lua.pop(child_len);

            arr[i - 1] = result.value;
        }

        return arr;
    }
};

pub const Userdata = struct {
    /// If the userdata at the given index has a metatable with
    /// a `__name` key which is a string, it leaves `__name`
    /// on the top of the stack.
    ///
    /// * Pops:   `0`
    /// * Pushes: `(0|1)`
    pub fn getNameFromLua(lua: *zlua.Lua, index: i32) bool {
        if (!lua.isUserdata(index)) {
            return false;
        }

        lua.getMetatable(index) catch {
            return false;
        };

        if (lua.getField(-1, "__name") != .string) {
            lua.pop(2);
            return false;
        }

        _ = lua.toString(-1) catch unreachable;
        lua.remove(lua.getTop() - 1);
        return true;
    }

    fn pushMetatable(lua: *zlua.Lua, comptime T: type, value: *T) void {
        const IndexFuncSig = ZLuaFuncSig;
        const NewindexFuncSig = ZLuaFuncSig;
        const ST = if (@typeInfo(T) == .pointer) @typeInfo(T).pointer.child else T;

        if (comptime StructMeta.from(ST)) |meta| {
            comptime {
                if (meta.fields) |fields| {
                    for (fields, 0..) |field, i| {
                        for (fields[i + 1 ..]) |other_field| {
                            var duplicate = std.mem.eql(u8, field.luaName(), other_field.luaName());
                            duplicate = duplicate and field == .method and other_field == .method;
                            duplicate = duplicate and
                                ((field.method.type == .getter and other_field.method.type == .setter) or
                                    (field.method.type == .setter and other_field.method.type == .getter));

                            if (duplicate) {
                                @compileError("found duplicate lua name '" ++ field.luaName ++ "' for '" ++ field.name ++ "' and '" ++ other_field.name ++ "' which are not setter and getter");
                            }
                        }

                        switch (field) {
                            .property => |p| {
                                if (!@hasField(ST, p.name)) {
                                    @compileError("'" ++ @typeName(T) ++ "' has no property: " ++ p.name);
                                }
                            },
                            else => {},
                        }
                    }
                }
            }

            if (blk: {
                lua.newMetatable(getLuaName(T)) catch break :blk false;
                break :blk true;
            }) {
                _ = lua.pushFunction(zlua.wrap(struct {
                    pub fn func(L: *zlua.Lua) i32 {
                        const struct_ptr = Lua.check(L, if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.is_const) *const ST else *ST, 1).value;
                        const field_name = L.checkString(2);

                        if (meta.fields) |fields| {
                            inline for (fields) |field| {
                                if (comptime field == .method and field.method.type == .setter) {
                                    continue;
                                }

                                if (std.mem.eql(u8, field.luaName(), field_name)) {
                                    field.push(L, T, struct_ptr);
                                    return 1;
                                }
                            }
                        }

                        L.pushNil();
                        return 1;
                    }
                }.func));
                lua.setField(-2, "__index");

                _ = lua.pushFunction(zlua.wrap(struct {
                    pub fn func(L: *zlua.Lua) i32 {
                        const struct_ptr = Lua.check(L, *ST, 1).value;
                        const key = Lua.check(L, [:0]const u8, 2).value;

                        if (meta.fields) |fields| {
                            inline for (fields) |field| {
                                if (comptime field == .method and field.method.type == .getter) {
                                    continue;
                                }

                                if (std.mem.eql(u8, field.luaName(), key)) {
                                    field.set(L, T, struct_ptr);
                                }
                            }
                        }

                        L.raiseErrorStr("no field found with key: '%s' in userdata: '%s'", .{ key.ptr, getLuaName(T).ptr });
                    }
                }.func));
                lua.setField(-2, "__newindex");

                if (meta.meta_fields) |meta_fields| {
                    inline for (meta_fields, 0..) |field, i| {
                        comptime {
                            if (std.mem.eql(u8, field.luaName(), "__index")) {
                                switch (field) {
                                    .property => @compileError(std.fmt.comptimePrint("expected '__index' in 'meta_fields' to be a method (T: {s})", .{@typeName(T)})),
                                    .method => |m| {
                                        if (m.ptr_type != *const IndexFuncSig) {
                                            @compileError(std.fmt.comptimePrint("'__index' meta method is expected to be a function of type: {s} (T: {s})", .{ @typeName(IndexFuncSig), @typeName(T) }));
                                        }
                                    },
                                }
                            } else if (std.mem.eql(u8, field.luaName(), "__newindex")) {
                                switch (field) {
                                    .property => @compileError(std.fmt.comptimePrint("expected '__newindex' in 'meta_fields' to be a method (T: {s})", .{@typeName(T)})),
                                    .method => |m| {
                                        if (m.ptr_type != *const NewindexFuncSig) {
                                            @compileError(std.fmt.comptimePrint("'__newindex' meta method is expected to be a function of type: {s} (T: {s})", .{ @typeName(NewindexFuncSig), @typeName(T) }));
                                        }
                                    },
                                }
                            }

                            for (meta_fields[i + 1 ..]) |other_field| {
                                var duplicate = std.mem.eql(u8, field.luaName(), other_field.luaName());
                                duplicate = duplicate and field == .method and other_field == .method;
                                duplicate = duplicate and
                                    ((field.method.type == .getter and other_field.method.type == .setter) or
                                        (field.method.type == .setter and other_field.method.type == .getter));

                                if (duplicate) {
                                    @compileError("found duplicate lua name '" ++ field.luaName ++ "' for '" ++ field.name ++ "' and '" ++ other_field.name ++ "' which are not setter and getter");
                                }
                            }
                        }

                        field.push(lua, T, value);
                        lua.setField(-2, field.luaName());
                    }
                }
            }
        } else {
            lua.newMetatable(getLuaName(T)) catch {}; //ignore error
        }
    }

    pub fn is(lua: *zlua.Lua, comptime T: type, index: i32) bool {
        if (getNameFromLua(lua, index)) {
            return false;
        }

        const lua_name = lua.toString(-1) catch unreachable;
        const userdata_name = getLuaName(T);
        return std.mem.eql(u8, lua_name, userdata_name);
    }

    pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !T {
        switch (@typeInfo(T)) {
            .@"struct",
            .@"union",
            => {
                return (try lua.toUserdata(T, index)).*;
            },
            .pointer => |p| {
                if (@typeInfo(p.child) != .@"struct") {
                    @compileError("can not get a pointer which doesn't directly point at a struct: " ++ @typeName(T) ++ " use 'Lua.get()'");
                }

                return (try lua.toUserdata(T, index)).*;
            },
            else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
        }
    }

    pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) T {
        if (!lua.isUserdata(index)) {
            lua.typeError(index, getLuaName(T));
        }

        switch (@typeInfo(T)) {
            .@"struct",
            .@"union",
            => {
                return (lua.toUserdata(T, index) catch unreachable).*;
            },
            .pointer => |p| {
                if (@typeInfo(p.child) != .@"struct") {
                    @compileError("can not get a pointer which doesn't directly point at a struct: " ++ @typeName(T) ++ " use 'Lua.check()'");
                }

                return lua.toUserdata(p.child, index) catch unreachable;
            },
            else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
        }
    }

    pub fn push(lua: *zlua.Lua, value: anytype) void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .@"struct",
            .@"union",
            => {
                const ptr: *T = lua.newUserdata(T, 0);
                ptr.* = value;

                pushMetatable(lua, T, ptr);
                lua.setMetatable(-2);
            },
            .pointer => |p| {
                if (@typeInfo(p.child) != .@"struct") {
                    @compileError("can not push a pointer which doesn't directly point at a struct: " ++ @typeName(T) ++ " use 'Lua.push()'");
                }

                const ptr: *T = lua.newUserdata(T, 0);
                ptr.* = value;

                pushMetatable(lua, T, ptr);
                lua.setMetatable(-2);
            },
            else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
        }
    }
};

pub const MultipleValues = struct {
    pub inline fn len(comptime info: std.builtin.Type.Struct) i32 {
        comptime {
            if (!info.is_tuple) {
                @compileError("type info expected to be a tuple");
            }

            var length: i32 = 0;
            for (info.fields) |field| {
                length += itemLen(field.type);
            }

            return length;
        }
    }

    pub fn is(lua: *zlua.Lua, comptime info: std.builtin.Type.Struct, index: i32) IndexCovered(bool) {
        if (!info.is_tuple) {
            @compileError("type info expected to be a tuple");
        }

        const abs_index = lua.absIndex(index);
        inline for (info.fields, 0..) |field, i| {
            if (!Lua.is(lua, field.type, abs_index + @as(i32, i)).value) {
                return IndexCovered(bool).many(false, @intCast(i + 1));
            }
        }

        return IndexCovered(bool).many(true, len(info));
    }

    pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !IndexCovered(T) {
        if (@typeInfo(T) != .@"struct") {
            @compileError("expected type to be a tuple");
        }
        const info = @typeInfo(T).@"struct";

        if (!info.is_tuple) {
            @compileError("type info expected to be a tuple");
        }

        const abs_index = lua.absIndex(index);

        var tuple: T = undefined;
        var covered_index: i32 = 0;
        inline for (info.fields, 0..) |field, i| {
            const result = try Lua.get(lua, field.type, @intCast(abs_index + covered_index));
            covered_index += result.len;
            tuple[i] = result.value;
        }

        return IndexCovered(T).many(tuple, covered_index);
    }

    pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) IndexCovered(T) {
        if (@typeInfo(T) != .@"struct") {
            @compileError("expected type to be a tuple");
        }
        const info = @typeInfo(T).@"struct";

        if (!info.is_tuple) {
            @compileError("type info expected to be a tuple");
        }

        const abs_index = lua.absIndex(index);

        var tuple: T = undefined;
        var covered_index: i32 = 0;
        inline for (info.fields, 0..) |field, i| {
            const result = Lua.get(lua, field.type, @intCast(abs_index + covered_index)) catch |err| {
                if (err == error.OutOfMemory) {
                    luaErrorOOM(lua);
                }

                lua.argError(index, getLuaName(T));
            };

            covered_index += result.len;
            tuple[i] = result.value;
        }

        return IndexCovered(T).many(tuple, covered_index);
    }

    pub fn push(lua: *zlua.Lua, value: anytype) void {
        const T = @TypeOf(value);
        if (@typeInfo(T) != .@"struct") {
            @compileError("expected type to be a tuple");
        }
        const info = @typeInfo(T).@"struct";

        if (!info.is_tuple) {
            @compileError("type info expected to be a tuple");
        }

        inline for (info.fields) |field| {
            Lua.push(lua, @field(value, field.name));
        }
    }
};

pub fn itemLen(comptime T: type) i32 {
    if (@typeInfo(T) == .@"struct" and @typeInfo(T).@"struct".is_tuple) {
        return MultipleValues.len(@typeInfo(T).@"struct");
    }

    return 1;
}

pub fn is(lua: *zlua.Lua, comptime T: type, index: i32) IndexCovered(bool) {
    if (lua.getTop() < lua.absIndex(index)) {
        return IndexCovered(bool).one(false);
    }

    if (T == Ref.Any) {
        return IndexCovered(bool).one(true);
    }

    if (T == Ref.Table) {
        return IndexCovered(bool).one(lua.isTable(index));
    }

    if (T == Ref.Func) {
        return IndexCovered(bool).one(lua.isFunction(index));
    }

    if (T == Ref.Userdata and !lua.isLightUserdata(index)) {
        return IndexCovered(bool).one(lua.isUserdata(index));
    }

    switch (@typeInfo(T)) {
        .int => {
            return IndexCovered(bool).one(lua.isInteger(index));
        },
        .float => {
            return IndexCovered(bool).one(lua.isNumber(index));
        },
        .bool => {
            return IndexCovered(bool).one(lua.isBoolean(index));
        },
        .pointer => |p| {
            if (comptime isStringType(T)) {
                return IndexCovered(bool).one(lua.isString(index));
            }

            if (comptime isArrayType(T)) {
                return IndexCovered(bool).one(Array.is(lua, p.child, index));
            }

            if (lua.isLightUserdata(index)) {
                return IndexCovered(bool).one(true);
            }

            if (@typeInfo(p.child) == .@"struct") {
                return IndexCovered(bool).one(Userdata.is(lua, T, index));
            }
        },
        .optional => |o| {
            if (lua.isNil(index)) {
                return IndexCovered(bool).one(true);
            }
            return is(lua, o.child, index);
        },
        .@"struct" => |s| {
            if (s.is_tuple) {
                return MultipleValues.is(lua, s, index);
            }

            return IndexCovered(bool).one(Userdata.is(lua, T, index));
        },
        .@"union" => {
            return IndexCovered(bool).one(Userdata.is(lua, T, index));
        },
        else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
    }
}

pub fn get(lua: *zlua.Lua, comptime T: type, index: i32) !IndexCovered(T) {
    if (T == Ref.Any) {
        return IndexCovered(T).one(Ref.Any.get(lua, index));
    }

    if (T == Ref.Table) {
        return IndexCovered(T).one(Ref.Table.init(lua, index));
    }

    if (T == Ref.Func) {
        return IndexCovered(T).one(Ref.Func.init(lua, index));
    }

    if (T == Ref.Userdata) {
        return IndexCovered(T).one(Ref.Userdata.init(lua, index));
    }

    switch (@typeInfo(T)) {
        .int => {
            const value: T = @intCast(try lua.toInteger(index));
            return IndexCovered(T).one(value);
        },
        .float => {
            const value: T = @floatCast(try lua.toNumber(index));
            return IndexCovered(T).one(value);
        },
        .bool => {
            return IndexCovered(T).one(lua.toBoolean(index));
        },
        .pointer => |p| {
            if (comptime isStringType(T)) {
                const str = @as(T, lua.toString(index) catch unreachable);
                return IndexCovered(T).one(str);
            }

            if (comptime @typeInfo(p.child) == .@"struct" and !isArrayType(T)) {
                const data = try Userdata.get(lua, T, index);
                return IndexCovered(T).one(data);
            }

            const ptr = @as(T, try lua.toUserdata(p.child, index));
            return IndexCovered(T).one(ptr);
        },
        .optional => |o| {
            if (lua.isNil(index) or lua.getTop() < index) {
                return IndexCovered(T).one(null);
            }
            const result = try get(lua, o.child, index);
            return IndexCovered(T).many(result.value, result.len);
        },
        .@"struct" => |s| {
            if (s.is_tuple) {
                return try MultipleValues.get(lua, T, index);
            }

            return IndexCovered(T).one(try Userdata.get(lua, T, index));
        },
        .@"union" => {
            return IndexCovered(T).one(try Userdata.get(lua, T, index));
        },
        else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
    }
}

pub fn check(lua: *zlua.Lua, comptime T: type, index: i32) IndexCovered(T) {
    if (T == Ref.Any) {
        return IndexCovered(T).one(Ref.Any.get(lua, index));
    }

    if (T == Ref.Table) {
        return IndexCovered(T).one(Ref.Table.check(lua, index));
    }

    if (T == Ref.Func) {
        return IndexCovered(T).one(Ref.Func.check(lua, index));
    }

    if (T == Ref.Userdata) {
        return IndexCovered(T).one(Ref.Userdata.check(lua, index));
    }

    switch (@typeInfo(T)) {
        .int,
        .float,
        => {
            return IndexCovered(T).one(lua.checkNumeric(T, index));
        },
        .bool => {
            if (!lua.isBoolean(index)) {
                lua.typeError(index, "boolean");
            }

            return IndexCovered(T).one(lua.toBoolean(index));
        },
        .pointer => |p| {
            if (!lua.isUserdata(index)) {
                lua.typeError(index, getLuaName(T));
            }

            if (comptime isStringType(T)) {
                const str = @as(T, lua.checkString(index));
                return IndexCovered(T).one(str);
            }

            if (comptime @typeInfo(p.child) == .@"struct" and !isArrayType(T)) {
                const data = Userdata.check(lua, T, index);
                return IndexCovered(T).one(data);
            }

            const ptr = @as(T, lua.toUserdata(p.child, index));
            return IndexCovered(T).one(ptr);
        },
        .optional => |o| {
            if (lua.isNil(index) or lua.getTop() < index) {
                return IndexCovered(T).one(null);
            }
            const result = check(lua, o.child, index);
            return IndexCovered(T).many(result.value, result.len);
        },
        .@"struct" => |s| {
            if (s.is_tuple) {
                return MultipleValues.check(lua, T, index);
            }

            return IndexCovered(T).one(Userdata.check(lua, T, index));
        },
        .@"union" => {
            return IndexCovered(T).one(Userdata.check(lua, T, index));
        },
        else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
    }
}

pub fn push(lua: *zlua.Lua, value: anytype) void {
    const T = @TypeOf(value);

    if (T == Ref.Any or
        T == Ref.Table or
        T == Ref.Func or
        T == Ref.Userdata)
    {
        value.push(lua);
    }

    return switch (@typeInfo(T)) {
        .int,
        .comptime_int,
        => lua.pushInteger(@intCast(value)),

        .float,
        .comptime_float,
        => lua.pushNumber(@floatCast(value)),

        .bool => lua.pushBoolean(value),

        .pointer => |p| {
            if (@typeInfo(p.child) == .@"fn") {
                lua.pushFunction(wrap(value));
                return;
            }

            if (comptime isStringType(T)) {
                if (p.sentinel()) |_| {
                    _ = lua.pushStringZ(value);
                    return;
                }
                _ = lua.pushString(value);
                return;
            }

            if (comptime @typeInfo(p.child) == .@"struct" and !isArrayType(T)) {
                Userdata.push(lua, value);
                return;
            }

            lua.pushLightUserdata(@ptrCast(@constCast(value)));
        },

        .optional => {
            if (value == null) {
                lua.pushNil();
                return;
            }

            push(lua, value.?);
        },

        .@"struct" => |s| {
            if (s.is_tuple) {
                MultipleValues.push(lua, value);
                return;
            }

            Userdata.push(lua, value);
            return;
        },

        .@"union" => Userdata.push(lua, value),

        else => @compileError(std.fmt.comptimePrint("not supported (T: {s})", .{@typeName(T)})),
    };
}

pub const ZLuaFuncSig = fn (lua: *zlua.Lua) i32;

pub const ReturnStackValues = struct {
    mode: Mode,

    pub const Mode = union(enum) {
        amount: i32,

        /// all extra stack values which were added during the function execution
        extra: void,

        /// all stack values
        all: void,
    };

    pub fn init(amount: i32) ReturnStackValues {
        return ReturnStackValues{ .mode = .{
            .amount = amount,
        } };
    }

    /// all extra stack values which were added during the function execution
    pub const extra = ReturnStackValues{
        .mode = .extra,
    };

    /// all stack values
    pub const all = ReturnStackValues{
        .mode = .all,
    };
};

/// the stack values of the parameter are left on the stack do **NOT REMOVE** them.
pub fn wrap(func: anytype) zlua.CFn {
    const FuncT = blk: switch (@typeInfo(@TypeOf(func))) {
        .pointer => |p| {
            if (@typeInfo(p.child) != .@"fn") {
                @compileError(std.fmt.comptimePrint("expected a function pointer (T: {s})", .{@typeName(@TypeOf(func))}));
            }

            if (@TypeOf(func) == zlua.CFn) {
                return func;
            }

            break :blk p.child;
        },
        .@"fn" => break :blk @TypeOf(func),
        else => @compileError(std.fmt.comptimePrint("expected a function (T: {s})", .{@typeName(@TypeOf(func))})),
    };

    if (FuncT == ZLuaFuncSig) {
        return zlua.wrap(func);
    }

    const info = @typeInfo(FuncT).@"fn";
    const has_error_union = @typeInfo(info.return_type.?) == .error_union;

    return zlua.wrap(struct {
        fn parseArgs(lua: *zlua.Lua) std.meta.ArgsTuple(FuncT) {
            const ArgsT: type = std.meta.ArgsTuple(FuncT);
            var args: ArgsT = undefined;

            var lua_arg_index: i32 = 1;
            inline for (@typeInfo(ArgsT).@"struct".fields, 0..) |param, i| {
                const ParamT = param.type;

                if (ParamT == ThisState) {
                    args[i] = ThisState.init(lua);
                    continue;
                }

                const result = check(lua, ParamT, lua_arg_index);
                lua_arg_index += result.len;
                args[i] = result.value;
            }

            return args;
        }

        pub fn call(lua: *zlua.Lua) i32 {
            const args_len = lua.getTop();
            const args = parseArgs(lua);

            const result = if (has_error_union)
                @call(.auto, func, args) catch |err| {
                    lua.raiseErrorStr(@errorName(err), .{});
                }
            else
                @call(.auto, func, args);
            const ReturnT: type = @TypeOf(result);

            if (ReturnT == void) {
                return 0;
            }
            if (ReturnT == ReturnStackValues) {
                const mode: ReturnStackValues.Mode = result.mode;
                switch (mode) {
                    .amount => |n| {
                        return n;
                    },
                    .extra => {
                        const diff = lua.getTop() - args_len;
                        if (diff >= 0) {
                            return diff;
                        }
                        return 0;
                    },
                    .all => {
                        return lua.getTop();
                    },
                }
            }

            push(lua, result);
            return itemLen(ReturnT);
        }
    }.call);
}

//TODO: tests
