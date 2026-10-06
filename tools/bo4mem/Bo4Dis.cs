// Disassembles Black Ops 4 code from memory, with Iced (the x86 disassembler, NuGet package Iced: its lib/net45/Iced.dll
// beside the exe).
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /r:Iced.dll /out:Bo4Dis.exe Bo4Dis.cs
//   run:   Bo4Dis.exe <hexaddr> <bytes>     absolute address, or exe+<hexoff>
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Iced.Intel;

static class Bo4Dis
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        var proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress;
        ulong at = args[0].StartsWith("exe+") ? b + Convert.ToUInt64(args[0].Substring(4), 16) : Convert.ToUInt64(args[0], 16);
        var code = new byte[Convert.ToInt32(args[1])];
        IntPtr got;
        if (!ReadProcessMemory(proc, (IntPtr)(long)at, code, (IntPtr)code.Length, out got)) { Console.WriteLine("unreadable"); return 2; }
        var dec = Decoder.Create(64, new ByteArrayCodeReader(code));
        dec.IP = at;
        while (dec.IP < at + (ulong)code.Length)
        {
            var ins = dec.Decode();
            Console.WriteLine("exe+{0:X} {1}", ins.IP - b, ins);
            if (ins.Mnemonic == Mnemonic.Int3) break;
        }
        return 0;
    }
}
