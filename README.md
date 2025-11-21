# Hudu

> **Note:** This README is AI-generated and may contain inaccuracies. While efforts are made to ensure correctness, please verify the information.

## Overview

Hudu is a simple "Hello World" web server written in Zig. It listens on port 5758 and responds to any request with a "Hello World!" message.

This project serves as a basic example of a TCP server implemented using the Zig standard library.

## Getting Started

To run the server, you need to have Zig installed.

1.  **Run the server:**
    ```sh
    zig build run
    ```
    The server will start on `http://127.0.0.1:5758`.

## Building from Source

To build the executable from source, run the following command:

```sh
zig build
```

The executable will be located in the `zig-out/bin` directory.