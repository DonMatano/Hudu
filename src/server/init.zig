const std = @import("std");
const net = std.net;
// const Io = std.Io;
const assert = std.debug.assert;
const Alloc = std.mem.Allocator;
const port = 5758;
const httpRequest = @import("httpRequest.zig");
const http = std.http;
const Io = std.Io;

pub fn run() !void {
    const IPAddress = try net.Ip4Address.parse("127.0.0.1", port);
    const address = net.Address{ .in = IPAddress };
    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    defer assert(debug_alloc.deinit() == .ok);
    // const alloc = debug_alloc.allocator();

    // var stdout_buffer: [1028]u8 = undefined;
    // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // var stdout = &stdout_writer.interface;

    var server = try address.listen(.{});
    defer server.deinit();
    std.log.info("\nStarting server on port: {d}\n", .{port});
    var receive_buffer: [1028]u8 = undefined;
    var send_buffer: [1028]u8 = undefined;

    const response = "Hello World!";

    while (true) {
        var connection = try server.accept();
        defer connection.stream.close();
        // const req = try httpRequest.parseHttpConnection(&connection, alloc);

        // std.debug.print("Request: {any}\n", .{req});
        var conn_reader = connection.stream.reader(&receive_buffer);
        var conn_writer = connection.stream.writer(&send_buffer);
        var local_server = std.http.Server.init(conn_reader.interface(), &conn_writer.interface);
        while (local_server.reader.state == .ready) {
            var request = local_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    std.log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            try request.respond(response, .{ .status = .ok });
        }
        // var read_slice_buffer: [1028]u8 = undefined;
        // std.debug.print("{s}", .{byte_as_string});
        // try stdout.print("{s}", .{se});
        // try stdout.flush();

        // std.log.info("\nResponse: \n {s}", .{response});
        // try writer.writeAll(response);
        // try writer.flush();
    }
}
