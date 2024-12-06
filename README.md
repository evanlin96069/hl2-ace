# Half-Life 2 Demo ACE

This project implements the exploit detailed [here](https://ctf.re/source-engine/exploitation/2021/05/01/source-engine-2/) in Half-Life 2 (build 2707) using a demo file.

Demo files are replay files for network packets, which makes it possible to use the same exploit. However, since all packets must be crafted beforehand, leaking the `engine.dll` base address and using it to create malicious packets to bypass ASLR is not feasible.

Build 2707 was chosen because the `engine.dll` is almost always loaded at the same address (0x20000000) in this version, eliminating the need to bypass ASLR. While most pre-Steampipe versions of the game don't have ASLR enabled, many of their DLLs share the same preferred address, causing them to be randomly relocated.
