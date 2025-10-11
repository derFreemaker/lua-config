pub fn IndexCovered(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        len: i32,

        pub fn one(value: T) Self {
            return Self{
                .value = value,
                .len = 1,
            };
        }

        pub fn many(value: T, len: i32) Self {
            return Self{
                .value = value,
                .len = len,
            };
        }
    };
}
