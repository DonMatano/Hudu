const std = @import("std");
const Hudu = @import("Hudu");

pub fn main(init: std.process.Init) !void {
    var hudu_server = try Hudu.init(init.io, init.arena.allocator());
    hudu_server.run(init.io, init.arena.allocator());
}
