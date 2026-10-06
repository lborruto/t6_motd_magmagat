// Bo4Pools: finds Black Ops 4's asset pool table in the running game and prints it. The table is an array of 0x20-byte
// entries { u64 pool; u32 itemSize; i32 itemCount; u32 pad; i32 itemAllocCount; u64 freeHead } (3 xanim, 4 xmodel,
// 9 image, 10 sound, 20 weapon, 33 fx), found the way Greyhound does (GameBlackOps4::LoadOffsets: the lea after
// 48 89 5C 24 ?? 57 48 83 EC ?? 0F B6 F9 48 8D 05 points at it). The other tools take its offset.
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:Bo4Pools.exe Bo4Pools.cs
//   run:   Bo4Pools.exe              the table's offset in BlackOps4.exe and its 120 entries
//          Bo4Pools.exe <hexoff>     the 120 entries at BlackOps4.exe+<hexoff>
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

static class Bo4Pools
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    static IntPtr proc;

    static byte[] Read(ulong addr, int len)
    {
        var b = new byte[len];
        IntPtr got;
        return ReadProcessMemory(proc, (IntPtr)(long)addr, b, (IntPtr)len, out got) ? b : null;
    }

    static void Print(ulong at)
    {
        var t = Read(at, 32 * 120);
        if (t == null) { Console.WriteLine("unreadable"); return; }
        for (int i = 0; i < 120; i++)
        {
            int o = 32 * i;
            Console.WriteLine("{0,3} size {1,6:X} count {2,7} alloc {3,7} pool {4:X}", i, BitConverter.ToUInt32(t, o + 8),
                BitConverter.ToInt32(t, o + 12), BitConverter.ToInt32(t, o + 20), BitConverter.ToUInt64(t, o));
        }
    }

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress;
        long size = p[0].MainModule.ModuleMemorySize;
        if (args.Length > 0) { Print(b + Convert.ToUInt64(args[0], 16)); return 0; }
        var sig = new int[] { 0x48, 0x89, 0x5C, 0x24, -1, 0x57, 0x48, 0x83, 0xEC, -1, 0x0F, 0xB6, 0xF9, 0x48, 0x8D, 0x05 };
        for (long off = 0; off < size; off += 0x100000 - 64)
        {
            int len = (int)Math.Min(0x100000, size - off);
            var d = Read(b + (ulong)off, len);
            if (d == null) continue;
            for (int o = 0; o + 20 <= len; o++)
            {
                int k = 0;
                while (k < sig.Length && (sig[k] < 0 || d[o + k] == sig[k])) k++;
                if (k < sig.Length) continue;
                ulong table = b + (ulong)off + (ulong)o + 0x14 + (ulong)(long)BitConverter.ToInt32(d, o + 0x10);
                Console.WriteLine("pool table at BlackOps4.exe+{0:X}", table - b);
                Print(table);
                return 0;
            }
        }
        Console.WriteLine("signature not found");
        return 2;
    }
}
