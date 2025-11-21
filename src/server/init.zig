const std = @import("std");
const net = std.net;
// const Io = std.Io;
const assert = std.debug.assert;
const port = 5758;

pub fn run() !void {
    const IPAddress = try net.Ip4Address.parse("127.0.0.1", port);
    const address = net.Address{ .in = IPAddress };

    var stdout_buffer: [1028]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var server = try address.listen(.{});
    // defer server.deinit();
    std.log.info("\nStarting server on port: {d}\n", .{port});
    var read_buffer: [1028]u8 = undefined;
    var write_buffer: [1028]u8 = undefined;

    const response = "HTTP/1.1 200 OK\r\nContent-Length: 12\r\n\r\nHello World!";

    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();
        var reader_wrapper = connection.stream.reader(&read_buffer);
        var reader = &reader_wrapper.interface_state;
        var writer_wrapper = connection.stream.writer(&write_buffer);
        var writer = &writer_wrapper.interface;

        std.log.info("Client Connected", .{});
        // var read_slice_buffer: [1028]u8 = undefined;
        const se = try reader.takeDelimiterInclusive('\n');
        // std.debug.print("{s}", .{byte_as_string});
        try stdout.print("{s}", .{se});
        try stdout.flush();

        std.log.info("\nResponse: \n {s}", .{response});
        try writer.writeAll(response);
        try writer.flush();
    }
}
