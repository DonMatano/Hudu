pub const Config = struct {
    port: u16,
};

pub const HTTP_METHOD = enum {
    GET,
    POST,
    PUT,
    DELETE,
    // TODO: Will add the other ones later. This is what I need to handle right now.
};
