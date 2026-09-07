const std = @import("std");
const Config = @import("types.zig").Config;
const assert = std.debug.assert;
const Alloc = std.mem.Allocator;
const httpRequest = @import("httpRequest.zig");
const http = std.http;
const Io = std.Io;
const net = Io.net;

const init_log = std.log.scoped(.InitLog);

pub fn run(config: Config, io: Io, alloc: Alloc) !void {
    _ = alloc;
    const address = try net.IpAddress.parseIp4("127.0.0.1", config.port);

    // const alloc = debug_alloc.allocator();

    // var stdout_buffer: [1028]u8 = undefined;
    // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // var stdout = &stdout_writer.interface;

    var server = try address.listen(io, .{ .reuse_address = true });
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
            init_log.debug("server status {any}", .{local_server.reader.state});
            var request = local_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    init_log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            init_log.debug("server status {any}", .{local_server.reader.state});
            var body_payload: [2048]u8 = undefined;
            if (request.head.content_length != null) {
                init_log.debug("content length {d}", .{request.head.content_length.?});
            }
            var body_reader = local_server.reader.bodyReader(&body_payload, request.head.transfer_encoding, request.head.content_length);
            const read_bytes = try body_reader.readSliceShort(&body_payload);
            init_log.debug("Received Body: \n{s}\n", .{body_payload[0..read_bytes]});
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
