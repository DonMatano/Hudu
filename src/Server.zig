const std = @import("std");
const Config = @import("server/types.zig").Config;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const http = std.http;
const Io = std.Io;
const net = Io.net;

const server_log = std.log.scoped(.ServerLog);

const Server = @This();

config: Config,
local_server: net.Server,

pub fn init(config: Config, io: Io, allocator: Allocator) !Server {
    _ = allocator;
    const address = try net.IpAddress.parseIp4("127.0.0.1", config.port);
    const s = try address.listen(io, .{ .reuse_address = true });

    return .{
        .config = config,
        .local_server = s,
    };
}

pub fn listen(s: *Server, io: Io, allocator: Allocator) !void {
    std.log.info("\nStarting server on port: {d}\n", .{s.config.port});
    const receive_buffer = try allocator.alloc(u8, 1028);
    const send_buffer = try allocator.alloc(u8, 1028);

    const response = "Hello World!";

    while (true) {
        var connection = try s.local_server.accept(io);
        defer connection.close(io);
        // const req = try httpRequest.parseHttpConnection(&connection, alloc);

        // std.debug.print("Request: {any}\n", .{req});
        var conn_reader = connection.reader(io, receive_buffer);
        var conn_writer = connection.writer(io, send_buffer);
        var http_server = std.http.Server.init(&conn_reader.interface, &conn_writer.interface);
        while (http_server.reader.state == .ready) {
            server_log.debug("server status {any}", .{http_server.reader.state});
            var request = http_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    server_log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            server_log.debug("server status {any}", .{http_server.reader.state});
            var body_payload: [2048]u8 = undefined;
            if (request.head.content_length != null) {
                server_log.debug("content length {d}", .{request.head.content_length.?});
            }
            var body_reader = http_server.reader.bodyReader(&body_payload, request.head.transfer_encoding, request.head.content_length);
            const read_bytes = try body_reader.readSliceShort(&body_payload);
            server_log.debug("Received Body: \n{s}\n", .{body_payload[0..read_bytes]});
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
