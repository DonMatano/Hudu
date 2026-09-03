const std = @import("std");
const Hudu = @import("Hudu");

pub fn main(init: std.process.Init) !void {
    try Hudu.init(init.io);
}
