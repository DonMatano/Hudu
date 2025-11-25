const std = @import("std");
const net = std.net;
const mem = std.mem;
const enums = std.enums;
const meta = std.meta;
const Io = std.Io;
pub const Request = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
};

pub const Method = enum {
    GET,
    fn mapMethod(method: []const u8) !Method {
        return meta.stringToEnum(Method, method) orelse error.MissingHTTPMethod;
    }
};
pub const HTTPProtocol = enum {
    @"1.1",
    fn mapProtocol(protocol_string: []const u8) !HTTPProtocol {
        const trimmed = protocol_string[0..(protocol_string.len - 2)]; // Assuming and removing last CRLF
        if (mem.eql(u8, trimmed, "HTTP/1.1")) {
            return .@"1.1";
        } else {
            return error.MissingHTTPProtocol;
        }
    }
};
// TODO LOOK how we can get the map working
// const http_protocol_map = enums.EnumMap([]const u8, HTTPProtocol).init(.{
//     .OnePointOne = "HTTP/1.1",
// });

const HTTPProtocolError = error{MalformedHTTPRequestLine};

const RequestLineData = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
    fn parseStartLine(reader: *Io.Reader) !RequestLineData {
        const request_first_line = try reader.peekDelimiterInclusive('\n');
        var splits = mem.splitScalar(u8, request_first_line, ' ');
        // Method Route Protocol
        // TODO: Update so that we can handle a CRLF possiblity on the first line
        const method = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
        const route = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;
        const protocol = splits.next() orelse return HTTPProtocolError.MalformedHTTPRequestLine;

        const enumMethod = try Method.mapMethod(method);
        const enumProtocol = try HTTPProtocol.mapProtocol(protocol);
        return .{
            .method = enumMethod,
            .route = route,
            .protocol = enumProtocol,
        };
    }
};
const HeaderData = struct {
    headers: std.StringHashMap([]const u8),
    pub fn parseHeader(reader: *Io.Reader, alloc: mem.Allocator) !HeaderData {
        var header = HeaderData{ .headers = std.StringHashMap([]const u8).init(alloc) };
        // Read till we find the empty line of CRLFCRLF
        var readRequestLine = false;
        read: while (reader.takeDelimiterInclusive('\n')) |data| {
            // If len is just two bytes of CRLF break We assume it's the end of headers
            if (data.len == 2) { // 2 bytes \r and \n
                break :read;
            }
            // Else check if it's first message line
            if (!readRequestLine) {
                readRequestLine = true;
                continue :read;
            }
            // Else handle a header
            const data_without_crlf = data[0 .. data.len - 2];
            const index_of_first_colon = mem.indexOfScalar(u8, data_without_crlf, ':') orelse {
                std.log.err("Missing collon in field value", .{});
                return error.MalformedHTTPHeader;
            };
            // TODO: Ensure in the future to check the validity of the field_value
            const field_value = data_without_crlf[0..index_of_first_colon];
            const field_content = data_without_crlf[index_of_first_colon + 1 ..];
            std.debug.print("Adding Header {s}: {s}\n", .{ field_value, field_content });
            try header.headers.put(field_value, field_content);
        } else |err| switch (err) {
            error.EndOfStream => break :read,
            else => return err
        }
        return header;
    }
    pub fn getHeader(self: *HeaderData, headerKey: []const u8) ?[]const u8 {
        return self.headers.get(headerKey);
    }
    pub fn deinit(self: *HeaderData) void {
        self.headers.deinit();
    }
};
pub fn parseHttpConnection(connection: *net.Server.Connection, alloc: mem.Allocator) !Request {
    var connection_read_buffer: [1028]u8 = undefined;
    var reader_wrapper = connection.stream.reader(&connection_read_buffer);
    const reader = &reader_wrapper.interface_state;
    // Get the first line
    const RequestLine = try RequestLineData.parseStartLine(reader);
    var header_data = try HeaderData.parseHeader(reader, alloc);
    defer header_data.deinit();
    var key_it = header_data.headers.keyIterator();
    std.debug.print("\nHEADERS:\n\n {d} headers \n", .{header_data.headers.count()});
    while (key_it.next()) |key| {
        if (header_data.headers.contains(key.*)) {
            std.debug.print("{s}: {s}\n", .{ key.*, header_data.headers.get(key.*).? });
        }
    }
    return .{
        .route = RequestLine.route,
        .method = RequestLine.method,
        .protocol = RequestLine.protocol,
    };
}
