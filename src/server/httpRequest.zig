const std = @import("std");
const net = std.net;
const mem = std.mem;
const enums = std.enums;
const meta = std.meta;
const Io = std.Io;
const testing = std.testing;
pub const Request = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
    headers: std.StringHashMap([]const u8),
};

pub const Method = enum {
    GET,
    POST,
    OPTIONS,
    fn mapMethod(method: []const u8) !Method {
        return meta.stringToEnum(Method, method) orelse error.MissingHTTPMethod;
    }
};
pub const HTTPProtocol = enum {
    @"1.1",
    fn mapProtocol(protocol_string: []const u8) !HTTPProtocol {
        if (mem.eql(u8, protocol_string, "HTTP/1.1")) {
            return .@"1.1";
        } else {
            std.log.err("Failed to get protocal for {s}", .{protocol_string});
            return error.MissingHTTPProtocol;
        }
    }
};
// TODO LOOK how we can get the map working
// const http_protocol_map = enums.EnumMap([]const u8, HTTPProtocol).init(.{
//     .OnePointOne = "HTTP/1.1",
// });

const HTTPProtocolError = error{MalformedHTTPRequestLine};
const HTTPErrors = error{BadRequest};

const RequestLineData = struct {
    route: []const u8,
    method: Method,
    protocol: HTTPProtocol,
    fn parseStartLine(reader: *Io.Reader) !RequestLineData {
        const request_first_line = try reader.peekDelimiterInclusive('\n');
        const breakLine = request_first_line[request_first_line.len - 2 ..];
        if (!mem.eql(u8, breakLine, "\r\n")) {
            std.log.err("Missing end break\t: Line ends with '{s}'", .{breakLine});
            return HTTPErrors.BadRequest;
        }
        var splits = mem.splitScalar(u8, request_first_line[0 .. request_first_line.len - 2], ' '); // remove last CRLF
        // Method Route Protocol
        // TODO: Update so that we can handle a CRLF possiblity on the first line
        // If it's more than 3 then we return a bad request
        var data: [3][]const u8 = [_][]const u8{ "", "", "" };
        var index: u2 = 0;
        while (splits.next()) |value| {
            if (value.len == 0 or index == 3) {
                std.log.err("Failed and got {s} for index {d}", .{ value, index });
                return HTTPErrors.BadRequest;
            }
            data[index] = value;
            index += 1;
            if (index >= 3) {
                break;
            }
        }
        const method = if (data[0].len > 0) data[0] else return HTTPErrors.BadRequest;
        const route = if (data[1].len > 0) data[1] else return HTTPErrors.BadRequest;
        const protocol = if (data[2].len > 0) data[2] else return HTTPErrors.BadRequest;

        const enumMethod = Method.mapMethod(method) catch |err| switch (err) {
            error.MissingHTTPMethod => {
                std.log.err("Got error for method: {s} - {}", .{ method, err });
                return HTTPErrors.BadRequest;
            }
        };
        const enumProtocol = HTTPProtocol.mapProtocol(protocol) catch |err| switch (err) {
            error.MissingHTTPProtocol => {
                std.log.err("Got Http Protocol error for protocol:{s} - {}", .{ protocol, err });
                return HTTPErrors.BadRequest;
            },
        };
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
    var connection_read_buffer: [1024]u8 = undefined;
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
        .headers = header_data.headers.move(),
    };
}

test "parseStartLine successfully parses startline" {
    const req = "GET / HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const request = try RequestLineData.parseStartLine(&reader);
    try testing.expectEqual(Method.GET, request.method);
    try testing.expectEqualStrings("/", request.route);
    try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
}

test "parseStartLine successfully parses request with complex URI" {
    const req = "POST /api/v1/users?sort=desc&limit=50 HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const request = try RequestLineData.parseStartLine(&reader);
    try testing.expectEqual(Method.POST, request.method);
    try testing.expectEqualStrings("/api/v1/users?sort=desc&limit=50", request.route);
    try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
}

test "parseStartLine successfully parses request with full proxy(http://) URI" {
    const req = "GET http://www.example.com/index.html HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const request = try RequestLineData.parseStartLine(&reader);
    try testing.expectEqual(Method.GET, request.method);
    try testing.expectEqualStrings("http://www.example.com/index.html", request.route);
    try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
}

test "parseStartLine successfully parses request with OPTION and a * as URI" {
    const req = "OPTIONS * HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const request = try RequestLineData.parseStartLine(&reader);
    try testing.expectEqual(Method.OPTIONS, request.method);
    try testing.expectEqualStrings("*", request.route);
    try testing.expectEqual(HTTPProtocol.@"1.1", request.protocol);
}
test "parseStartLine throws error when parsing a extra spaced malformed URI" {
    const req = "GET    /     HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when parsing a truncated Line" {
    const req = "GET /api/data\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when protocol doesn't start with HTTP" {
    const req = "POST / HTTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when it's a garbage request" {
    const req = "12345 INVALID REQUEST\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when method is lowercase" {
    const req = "get / HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when line ends with just LF" {
    const req = "GET / HTTP/1.1\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when there is unencoded space on the URI" {
    const req = "GET /my file.html HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
test "parseStartLine throws error when the Request line is too long. " {
    const req = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA / HTTP/1.1\r\n";
    var reader = Io.Reader.fixed(req);
    const expectedError = error.BadRequest;
    try testing.expectError(expectedError, RequestLineData.parseStartLine(&reader));
}
