// Bo4Fields: Black Ops 4's GSC weapon-field table (what a script reads as weapon.firetime...): 0x20-byte entries
// { u32 name hash, u32 type, u32, u32 offset in the WeaponDef or its tunables, ..., u64 getter }, at
// BlackOps4.exe+0x4961000 on the build this was written on. Names hash as acts' HashT89Scr. A field with a getter
// is computed: disassemble the getter (Bo4Dis) for the offset it reads (fire time: tunables +0xD10, ms).
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:Bo4Fields.exe Bo4Fields.cs
//   run:   Bo4Fields.exe <name> [name...]                    where the names' hashes are in the exe (finds the table)
//          Bo4Fields.exe --table <hexoff> <count> [names]   the table at BlackOps4.exe+<hexoff>, naming the given names
//          Bo4Fields.exe --code <hexaddr> <bytes>           raw bytes at an address (a getter, a struct)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

static class Bo4Fields
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    // acts hash::HashT89Scr: the GSC canonical-name hash
    static uint Scr(string s)
    {
        uint h = 0x4B9ACE2F;
        foreach (byte c in Encoding.ASCII.GetBytes(s.ToLowerInvariant())) { uint t = c + h; h = (t ^ (t << 10)) + ((t ^ (t << 10)) >> 6); }
        return 0x8001 * ((9 * h) ^ ((9 * h) >> 11));
    }

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        var proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress;
        long size = p[0].MainModule.ModuleMemorySize;
        if (args[0] == "--table" || args[0] == "--code")
        {
            ulong at = args[0] == "--table" ? b + Convert.ToUInt64(args[1], 16) : Convert.ToUInt64(args[1], 16);
            int n = Convert.ToInt32(args[2]);
            var names = new Dictionary<uint, string>();
            for (int i = 3; i < args.Length; i++) names[Scr(args[i])] = args[i];
            var t = new byte[args[0] == "--table" ? n * 32 : n];
            IntPtr r;
            if (!ReadProcessMemory(proc, (IntPtr)(long)at, t, (IntPtr)t.Length, out r)) { Console.WriteLine("unreadable"); return 2; }
            if (args[0] == "--code") { for (int i = 0; i < n; i++) Console.Write("{0:X2}{1}", t[i], i % 16 == 15 ? "\n" : " "); Console.WriteLine(); return 0; }
            for (int i = 0; i < n; i++)
            {
                int o = 32 * i; string nm;
                uint h = BitConverter.ToUInt32(t, o);
                names.TryGetValue(h, out nm);
                Console.WriteLine("{0,3} {1:X8} type {2,2} {3} off {4:X5} {5:X8} {6:X8} fn {7:X} {8}", i, h, BitConverter.ToUInt32(t, o + 4), BitConverter.ToUInt32(t, o + 8),
                    BitConverter.ToUInt32(t, o + 12), BitConverter.ToUInt32(t, o + 16), BitConverter.ToUInt32(t, o + 20), BitConverter.ToUInt64(t, o + 24), nm ?? "");
            }
            return 0;
        }
        var want = new Dictionary<uint, string>();
        foreach (var n in args)
        {
            want[Scr(n)] = n;
        }
        const int CH = 0x100000; int bad = 0;
        for (long off = 0; off < size; off += CH - 64)
        {
            int len = (int)Math.Min(CH, size - off);
            var d = new byte[len];
            IntPtr got;
            if (!ReadProcessMemory(proc, (IntPtr)(long)(b + (ulong)off), d, (IntPtr)len, out got)) { bad++; continue; }
            for (int o = 0; o + 36 <= len; o++)
            {
                string n;
                if (!want.TryGetValue(BitConverter.ToUInt32(d, o), out n)) continue;
                var sb = new StringBuilder();
                for (int k = o; k < o + 32; k += 4) sb.AppendFormat(" {0:X8}", BitConverter.ToUInt32(d, k));
                Console.WriteLine("{0,-24} exe+{1:X}:{2}", n, off + o, sb);
            }
        }
        Console.WriteLine("image {0:X}, unreadable 1 MB chunks: {1}", size, bad);
        return 0;
    }
}
