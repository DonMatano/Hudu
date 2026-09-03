const std = @import("std");
const Config = @import("types.zig").Config;
const assert = std.debug.assert;
const Alloc = std.mem.Allocator;
const httpRequest = @import("httpRequest.zig");
const http = std.http;
const Io = std.Io;
const net = Io.net;

pub fn run(config: Config, io: Io) !void {
    const address = try net.IpAddress.parseIp4("127.0.0.1", config.port);

    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    defer assert(debug_alloc.deinit() == .ok);
    // const alloc = debug_alloc.allocator();

    // var stdout_buffer: [1028]u8 = undefined;
    // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // var stdout = &stdout_writer.interface;

    var server = try address.listen(io, .{});
    defer server.deinit(io);
    std.log.info("\nStarting server on port: {d}\n", .{config.port});
    var receive_buffer: [1028]u8 = undefined;
    var send_buffer: [1028]u8 = undefined;

    const response = "Hello World!";

    while (true) {
        var connection = try server.accept(io);
        defer connection.close(io);
        // const req = try httpRequest.parseHttpConnection(&connection, alloc);

        // std.debug.print("Request: {any}\n", .{req});
        var conn_reader = connection.reader(io, &receive_buffer);
        var conn_writer = connection.writer(io, &send_buffer);
        var local_server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
        while (local_server.reader.state == .ready) {
            var request = local_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    std.log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            var headers_iterator = request.iterateHeaders();
            while (headers_iterator.next()) |header| {
                std.log.debug("Name: {s}\n", .{header.name});
                std.log.debug("Value: {s}\n", .{header.name});
            }
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
