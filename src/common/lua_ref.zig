const std = @import("std");
const zlua = @import("zlua");

pub const Ref = struct {
    lua: *zlua.Lua,
    index: i32,

    pub fn init(lua: *zlua.Lua, index: i32) Ref {
        return Ref{
            .lua = lua,
            .index = lua.absIndex(index),
        };
    }

    pub fn push(self: *const Ref, move_lua: ?*zlua.Lua) void {
        self.lua.pushValue(self.index);

        if (move_lua != null and self.lua != move_lua.?) {
            self.lua.xMove(move_lua.?, 1);
        }
    }
};

pub const Table = struct {
    const Self = @This();

    ref: Ref,

    pub fn init(lua: *zlua.Lua, index: i32) Self {
        return Self{
            .ref = Ref.init(lua, index),
        };
    }

    pub fn check(lua: *zlua.Lua, index: i32) Self {
        lua.checkType(index, .table);
        return init(lua, index);
    }

    pub fn push(self: *const Self, lua: ?*zlua.Lua) void {
        self.ref.push(lua);
    }
};

pub const Func = struct {
    const Self = @This();

    ref: Ref,

    pub fn init(lua: *zlua.Lua, index: i32) Self {
        return Self{
            .ref = Ref.init(lua, index),
        };
    }

    pub fn check(lua: *zlua.Lua, index: i32) Self {
        lua.checkType(index, .function);
        return init(lua, index);
    }

    pub fn push(self: *const Self, lua: ?*zlua.Lua) void {
        self.ref.push(lua);
    }
};

pub const Userdata = struct {
    const Self = @This();

    ref: Ref,
    ptr: *anyopaque,

    pub fn init(lua: *zlua.Lua, index: i32) Self {
        return Self{
            .ref = Ref.init(lua, index),
            .ptr = lua.toUserdata(anyopaque, index) catch unreachable,
        };
    }

    pub fn check(lua: *zlua.Lua, index: i32) Self {
        if (!lua.isUserdata(index)) {
            lua.typeError(index, "light-/userdata");
        }
        return init(lua, index);
    }

    pub fn push(self: *const Self, lua: ?*zlua.Lua) void {
        self.ref.push(lua);
    }
};

pub const Any = union(enum) {
    const Self = @This();
    
    none: void,
    nil: void,
    boolean: bool,
    integer: i64,
    number: f64,
    string: [:0]const u8,
    table: Table,
    function: Func,
    light_userdata: *anyopaque,
    userdata: Userdata,
    thread: *zlua.Lua,

    pub fn get(lua: *zlua.Lua, index: i32) Self {
        return switch (lua.typeOf(index)) {
            .none => Self{ .none = {} },
            .nil => Self{ .nil = {} },
            .boolean => Self{ .boolean = lua.toBoolean(index) },
            .number => {
                if (lua.isInteger(index)) {
                    return Self{ .integer = @intCast(lua.toInteger(index) catch unreachable) };
                }

                return Self{ .number = lua.toNumber(index) catch unreachable };
            },
            .string => Self{ .string = lua.toString(index) catch unreachable },
            .table => Self{ .table = Table.init(index) },
            .function => Self{ .function = Func.init(lua, index) },
            .light_userdata => Self{ .light_userdata = lua.toUserdata(anyopaque, index) catch unreachable },
            .userdata => Self{ .userdata = Userdata.init(lua, index) },
            .thread => Self{ .thread = lua.toThread(index) catch unreachable },
        };
    }

    pub fn push(self: *const Self, lua: *zlua.Lua) void {
        switch (self.*) {
            .none => {},
            .nil => lua.pushNil(),
            .boolean => |b| lua.pushBoolean(b),
            .number => |n| lua.pushNumber(n),
            .string => |s| lua.pushStringZ(s),
            .table => |t| t.ref.push(lua),
            .function => |f| f.ref.push(lua),
            .light_userdata => |ptr| lua.pushLightUserdata(ptr),
            .userdata => |ud| ud.ref.push(lua),
            .thread => |t| {
                _ = t.pushThread();
                t.xMove(lua, 1);
            },
        }
    }
};
