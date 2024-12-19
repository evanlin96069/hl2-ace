# Half-Life 2 Demo ACE

Demo files are replay files for network packets, which means old RCE exploits related to network packets are also possible in demo files.
Unlike having a malicious server, all packets in the demo file must be crafted beforehand, leaking base addresses of certain modules and using them to create malicious packets to bypass ASLR is not feasible. We have to use older versions of the game because the latest version has ASLR enabled on all modules.

## Portal (Build 5135)

Exploit: [Portal 2 Remote Code Execution via voice packets](https://hackerone.com/reports/733267)

Using `launcher.dll` to start the ROP chain after the buffer overflow in the `SvcVoiceData` packet.

## Half-Life 2 (Build 2707)

Exploit: [Source Engine Packetentities RCE](https://ctf.re/source-engine/exploitation/2021/05/01/source-engine-2/)

Build 2707 was chosen because the `engine.dll` is almost always loaded at the same address (0x20000000) in this version, eliminating the need to bypass ASLR.
