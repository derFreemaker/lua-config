const std = @import("std");
const windows = std.os.windows;

pub const RegistryError = error{
    KeyNotFound,
    ValueNotFound,
    AccessDenied,
    InvalidParameter,
    OutOfMemory,
    BufferTooSmall,
    UnsupportedType,
    KeyDeleted,
    UnknownError,
};

pub const ValueType = enum {
    String,
    ExpandString,
    Binary,
    Dword,
    DwordBigEndian,
    Link,
    MultiString,
    Qword,

    pub fn toWindowsType(self: ValueType) u32 {
        return switch (self) {
            .String => windows.REG.SZ,
            .ExpandString => windows.REG.EXPAND_SZ,
            .Binary => windows.REG.BINARY,
            .Dword => windows.REG.DWORD,
            .DwordBigEndian => windows.REG.DWORD_BIG_ENDIAN,
            .Link => windows.REG.LINK,
            .MultiString => windows.REG.MULTI_SZ,
            .Qword => windows.REG.QWORD,
        };
    }

    pub fn fromWindowsType(win_type: u32) ?ValueType {
        return switch (win_type) {
            windows.REG.SZ => .String,
            windows.REG.EXPAND_SZ => .ExpandString,
            windows.REG.BINARY => .Binary,
            windows.REG.DWORD => .Dword,
            windows.REG.DWORD_BIG_ENDIAN => .DwordBigEndian,
            windows.REG.LINK => .Link,
            windows.REG.MULTI_SZ => .MultiString,
            windows.REG.QWORD => .Qword,
            else => null,
        };
    }
};

pub const KeyAccess = struct {
    pub const READ = windows.KEY_READ;
    pub const WRITE = windows.KEY_WRITE;
    pub const ALL = windows.KEY_ALL_ACCESS;
    pub const QUERY = windows.KEY_QUERY_VALUE;
    pub const SET = windows.KEY_SET_VALUE;
    pub const CREATE_SUB_KEY = windows.KEY_CREATE_SUB_KEY;
    pub const ENUMERATE_SUB_KEYS = windows.KEY_ENUMERATE_SUB_KEYS;
};

pub const RootKey = enum(usize) {
    ClassesRoot = 0x80000000,
    CurrentUser = 0x80000001,
    LocalMachine = 0x80000002,
    Users = 0x80000003,
    CurrentConfig = 0x80000005,

    pub fn toHKEY(self: RootKey) windows.HKEY {
        return @ptrFromInt(@intFromEnum(self));
    }
};

pub const ValueInfo = struct {
    name: []const u8,
    value_type: ValueType,
};

pub const SubKeyInfo = struct {
    name: []const u8,
};

pub const RegistryKey = struct {
    handle: windows.HKEY,
    allocator: std.mem.Allocator,
    owns_handle: bool,

    const Self = @This();

    /// Open a registry key
    pub fn open(allocator: std.mem.Allocator, root: RootKey, subkey: []const u8, access: u32) RegistryError!Self {
        var handle: windows.HKEY = undefined;

        const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey) catch return RegistryError.OutOfMemory;
        defer allocator.free(subkey_w);

        const result = windows.advapi32.RegOpenKeyExW(
            root.toHKEY(),
            subkey_w.ptr,
            0,
            access,
            &handle,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        return Self{
            .handle = handle,
            .allocator = allocator,
            .owns_handle = true,
        };
    }

    /// Create a new registry key (or open if exists)
    pub fn create(allocator: std.mem.Allocator, root: RootKey, subkey: []const u8, access: u32) RegistryError!Self {
        var handle: windows.HKEY = undefined;
        var disposition: u32 = undefined;

        const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, subkey) catch return RegistryError.OutOfMemory;
        defer allocator.free(subkey_w);

        const result = RegCreateKeyExW(
            root.toHKEY(),
            subkey_w.ptr,
            0,
            null,
            0, // REG_OPTION_NON_VOLATILE
            access,
            null,
            &handle,
            &disposition,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        return Self{
            .handle = handle,
            .allocator = allocator,
            .owns_handle = true,
        };
    }

    /// Close the registry key
    pub fn close(self: *Self) void {
        if (self.owns_handle) {
            _ = windows.advapi32.RegCloseKey(self.handle);
            self.owns_handle = false;
        }
    }

    /// Read a string value
    pub fn readString(self: Self, value_name: []const u8) RegistryError![]u8 {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        var size: u32 = 0;
        var value_type: u32 = undefined;

        // First call to get size
        var result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            null,
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        if (value_type != windows.REG.SZ and value_type != windows.REG.EXPAND_SZ) {
            return RegistryError.UnsupportedType;
        }

        // Allocate buffer for UTF-16 data
        const buffer_w = self.allocator.alloc(u16, size / 2) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(buffer_w);

        result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            @ptrCast(buffer_w.ptr),
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        // Find null terminator
        var len: usize = 0;
        while (len < buffer_w.len and buffer_w[len] != 0) : (len += 1) {}

        // Convert to UTF-8
        return std.unicode.utf16LeToUtf8Alloc(self.allocator, buffer_w[0..len]) catch return RegistryError.OutOfMemory;
    }

    /// Write a string value
    pub fn writeString(self: Self, value_name: []const u8, data: []const u8) RegistryError!void {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        const data_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, data) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(data_w);

        const result = RegSetValueExW(
            self.handle,
            value_name_w.ptr,
            0,
            windows.REG.SZ,
            @ptrCast(data_w.ptr),
            @intCast(data_w.len * 2),
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Read a DWORD value
    pub fn readDword(self: Self, value_name: []const u8) RegistryError!u32 {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        var data: u32 = undefined;
        var size: u32 = @sizeOf(u32);
        var value_type: u32 = undefined;

        const result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            @ptrCast(&data),
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        if (value_type != windows.REG.DWORD) {
            return RegistryError.UnsupportedType;
        }

        return data;
    }

    /// Write a DWORD value
    pub fn writeDword(self: Self, value_name: []const u8, data: u32) RegistryError!void {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        const result = RegSetValueExW(
            self.handle,
            value_name_w.ptr,
            0,
            windows.REG.DWORD,
            @ptrCast(&data),
            @sizeOf(u32),
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Read a QWORD value
    pub fn readQword(self: Self, value_name: []const u8) RegistryError!u64 {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        var data: u64 = undefined;
        var size: u32 = @sizeOf(u64);
        var value_type: u32 = undefined;

        const result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            @ptrCast(&data),
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        if (value_type != windows.REG.QWORD) {
            return RegistryError.UnsupportedType;
        }

        return data;
    }

    /// Write a QWORD value
    pub fn writeQword(self: Self, value_name: []const u8, data: u64) RegistryError!void {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        const result = RegSetValueExW(
            self.handle,
            value_name_w.ptr,
            0,
            windows.REG.QWORD,
            @ptrCast(&data),
            @sizeOf(u64),
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Read binary data
    pub fn readBinary(self: Self, value_name: []const u8) RegistryError![]u8 {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        var size: u32 = 0;
        var value_type: u32 = undefined;

        // First call to get size
        var result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            null,
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        if (value_type != windows.REG.BINARY) {
            return RegistryError.UnsupportedType;
        }

        const buffer = self.allocator.alloc(u8, size) catch return RegistryError.OutOfMemory;
        errdefer self.allocator.free(buffer);

        result = windows.advapi32.RegQueryValueExW(
            self.handle,
            value_name_w.ptr,
            null,
            &value_type,
            buffer.ptr,
            &size,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        return buffer;
    }

    /// Write binary data
    pub fn writeBinary(self: Self, value_name: []const u8, data: []const u8) RegistryError!void {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        const result = RegSetValueExW(
            self.handle,
            value_name_w.ptr,
            0,
            windows.REG.BINARY,
            data.ptr,
            @intCast(data.len),
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Delete a value
    pub fn deleteValue(self: Self, value_name: []const u8) RegistryError!void {
        const value_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, value_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(value_name_w);

        const result = RegDeleteValueW(self.handle, value_name_w.ptr);

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Delete a subkey (must be empty)
    pub fn deleteSubKey(self: Self, subkey_name: []const u8) RegistryError!void {
        const subkey_name_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, subkey_name) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(subkey_name_w);

        const result = RegDeleteKeyW(self.handle, subkey_name_w.ptr);

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }
    }

    /// Enumerate all values in the key
    pub fn enumerateValues(self: Self) RegistryError![]ValueInfo {
        var values = std.ArrayList(ValueInfo).init(self.allocator);
        errdefer {
            for (values.items) |val| {
                self.allocator.free(val.name);
            }
            values.deinit();
        }

        var index: u32 = 0;
        while (true) : (index += 1) {
            var name_buffer: [256]u16 = undefined;
            var name_len: u32 = name_buffer.len;
            var value_type: u32 = undefined;

            const result = RegEnumValueW(
                self.handle,
                index,
                &name_buffer,
                &name_len,
                null,
                &value_type,
                null,
                null,
            );

            if (result == windows.Win32Error.NO_MORE_ITEMS) {
                break;
            }

            if (result != 0) {
                return windowsErrorToRegistry(result);
            }

            const name_utf8 = std.unicode.utf16LeToUtf8Alloc(self.allocator, name_buffer[0..name_len]) catch return RegistryError.OutOfMemory;
            errdefer self.allocator.free(name_utf8);

            const vtype = ValueType.fromWindowsType(value_type) orelse .Binary;

            try values.append(ValueInfo{
                .name = name_utf8,
                .value_type = vtype,
            });
        }

        return values.toOwnedSlice();
    }

    /// Enumerate all subkeys
    pub fn enumerateSubKeys(self: Self) RegistryError![]SubKeyInfo {
        var subkeys = std.ArrayList(SubKeyInfo).init(self.allocator);
        errdefer {
            for (subkeys.items) |key| {
                self.allocator.free(key.name);
            }
            subkeys.deinit();
        }

        var index: u32 = 0;
        while (true) : (index += 1) {
            var name_buffer: [256]u16 = undefined;
            var name_len: u32 = name_buffer.len;

            const result = RegEnumKeyExW(
                self.handle,
                index,
                &name_buffer,
                &name_len,
                null,
                null,
                null,
                null,
            );

            if (result == windows.Win32Error.NO_MORE_ITEMS) {
                break;
            }

            if (result != 0) {
                return windowsErrorToRegistry(result);
            }

            const name_utf8 = std.unicode.utf16LeToUtf8Alloc(self.allocator, name_buffer[0..name_len]) catch return RegistryError.OutOfMemory;
            errdefer self.allocator.free(name_utf8);

            try subkeys.append(SubKeyInfo{
                .name = name_utf8,
            });
        }

        return subkeys.toOwnedSlice();
    }

    /// Open a subkey relative to this key
    pub fn openSubKey(self: Self, subkey: []const u8, access: u32) RegistryError!RegistryKey {
        var handle: windows.HKEY = undefined;

        const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, subkey) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(subkey_w);

        const result = windows.advapi32.RegOpenKeyExW(
            self.handle,
            subkey_w.ptr,
            0,
            access,
            &handle,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        return RegistryKey{
            .handle = handle,
            .allocator = self.allocator,
            .owns_handle = true,
        };
    }

    /// Create a subkey relative to this key
    pub fn createSubKey(self: Self, subkey: []const u8, access: u32) RegistryError!RegistryKey {
        var handle: windows.HKEY = undefined;
        var disposition: u32 = undefined;

        const subkey_w = std.unicode.utf8ToUtf16LeAllocZ(self.allocator, subkey) catch return RegistryError.OutOfMemory;
        defer self.allocator.free(subkey_w);

        const result = RegCreateKeyExW(
            self.handle,
            subkey_w.ptr,
            0,
            null,
            0,
            access,
            null,
            &handle,
            &disposition,
        );

        if (result != 0) {
            return windowsErrorToRegistry(result);
        }

        return RegistryKey{
            .handle = handle,
            .allocator = self.allocator,
            .owns_handle = true,
        };
    }
};

fn windowsErrorToRegistry(err: windows.Win32Error) RegistryError {
    return switch (err) {
        .FILE_NOT_FOUND, .PATH_NOT_FOUND => RegistryError.KeyNotFound,
        .ACCESS_DENIED => RegistryError.AccessDenied,
        .INVALID_PARAMETER => RegistryError.InvalidParameter,
        .OUTOFMEMORY => RegistryError.OutOfMemory,
        .MORE_DATA => RegistryError.BufferTooSmall,
        .KEY_DELETED => RegistryError.KeyDeleted,
        else => RegistryError.UnknownError,
    };
}

extern "advapi32" fn RegCreateKeyExW(
    hKey: windows.HKEY,
    lpSubKey: [*:0]const u16,
    Reserved: u32,
    lpClass: ?*u16,
    dwOptions: u32,
    samDesired: u32,
    lpSecurityAttributes: ?*anyopaque,
    phkResult: *windows.HKEY,
    lpdwDisposition: *u32,
) callconv(.winapi) windows.Win32Error;

extern "advapi32" fn RegSetValueExW(
    hKey: windows.HKEY,
    lpValueName: [*:0]const u16,
    Reserved: u32,
    dwType: u32,
    lpData: [*]const u8,
    cbData: u32,
) callconv(.winapi) windows.Win32Error;

extern "advapi32" fn RegDeleteValueW(
    hKey: windows.HKEY,
    lpValueName: [*:0]const u16,
) callconv(.winapi) windows.Win32Error;

extern "advapi32" fn RegDeleteKeyW(
    hKey: windows.HKEY,
    lpSubKey: [*:0]const u16,
) callconv(.winapi) windows.Win32Error;

extern "advapi32" fn RegEnumValueW(
    hKey: windows.HKEY,
    dwIndex: u32,
    lpValueName: [*]u16,
    lpcchValueName: *u32,
    lpReserved: ?*u32,
    lpType: ?*u32,
    lpData: ?[*]u8,
    lpcbData: ?*u32,
) callconv(.winapi) windows.Win32Error;

extern "advapi32" fn RegEnumKeyExW(
    hKey: windows.HKEY,
    dwIndex: u32,
    lpName: [*]u16,
    lpcchName: *u32,
    lpReserved: ?*u32,
    lpClass: ?[*]u16,
    lpcchClass: ?*u32,
    lpftLastWriteTime: ?*windows.FILETIME,
) callconv(.winapi) windows.Win32Error;
