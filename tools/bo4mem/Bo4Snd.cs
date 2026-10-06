// Dumps every sound alias Black Ops 4 has loaded: walks the sound pool (index 10 of the pool table, SndBank 0x130,
// layouts from atian-cod-tools' bo4_unlinker_sound.cpp) and prints, per alias variant:
//   bank zone, alias name hash, variant index, secondary alias hash, asset id, sustain asset id, release asset id
// (hashes as 16 hex digits; XHash = { u64 hash, u64 string }). An alias hash is fnv1a-64 of its name, top bit clear; a
// secondary alias plays with its alias (a layer); an asset id's low 60 bits name its file in the banks
// (MgBo3::bo4_file_id). The tail of a variant: +0xA8 flags (bit 0 looping, bit 1 3D), +0x180 linear volume min / max
// (floats), +0x198 distances (u16: min, max dry, max wet). tools/assets/bo4_sounds.tsv was built from it.
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:Bo4Snd.exe Bo4Snd.cs
//   run:   Bo4Snd.exe <pool table hexoff> > aliases.tsv
//   Bo4Snd.exe <pool table hexoff> <alias hash> [variant]   raw qwords of a variant (default the first)
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

static class Bo4Snd
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    static IntPtr proc;

    static byte[] Read(ulong addr, int len)
    {
        if (addr < 0x10000 || len <= 0) return null;
        var b = new byte[len];
        IntPtr got;
        return ReadProcessMemory(proc, (IntPtr)(long)addr, b, (IntPtr)len, out got) ? b : null;
    }

    static string Str(ulong addr)
    {
        var b = Read(addr, 64);
        if (b == null) return "";
        int n = Array.IndexOf(b, (byte)0);
        return Encoding.ASCII.GetString(b, 0, n < 0 ? 64 : n);
    }

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress;
        var e = Read(b + Convert.ToUInt64(args[0], 16) + 10 * 0x20, 0x20);
        ulong pool = BitConverter.ToUInt64(e, 0);
        uint size = BitConverter.ToUInt32(e, 8), count = BitConverter.ToUInt32(e, 12);
        Console.Error.WriteLine("sound pool {0:X}, item {1:X}, {2} slots", pool, size, count);
        int banks = 0, rows = 0;
        for (uint i = 0; i < count; i++)
        {
            var bank = Read(pool + i * size, 0x130);
            if (bank == null) continue;
            uint aliasCount = BitConverter.ToUInt32(bank, 0x30);
            ulong alias = BitConverter.ToUInt64(bank, 0x38);
            if (args.Length > 1 && aliasCount > 0) { var ls = Read(BitConverter.ToUInt64(bank, 0x38), (int)aliasCount * 0x28); for (int k = 0; ls != null && k < aliasCount; k++) if (BitConverter.ToUInt64(ls, k * 0x28).ToString("x16") == args[1]) { var one = Read(BitConverter.ToUInt64(ls, k * 0x28 + 0x10) + (ulong)(args.Length > 2 ? int.Parse(args[2]) : 0) * 0x1C0, 0x1C0); for (int q = 0; q < 0x1C0; q += 8) Console.WriteLine("+{0:X3} {1:X16}", q, BitConverter.ToUInt64(one, q)); return 0; } continue; }
            if (aliasCount == 0 || aliasCount > 200000 || alias < 0x10000) continue;
            string zone = Str(BitConverter.ToUInt64(bank, 0x18));
            if (zone == "") zone = Str(BitConverter.ToUInt64(bank, 0));
            var lists = Read(alias, (int)aliasCount * 0x28);
            if (lists == null) continue;
            banks++;
            for (int k = 0; k < aliasCount; k++)
            {
                int o = k * 0x28;
                ulong name = BitConverter.ToUInt64(lists, o);
                ulong arr = BitConverter.ToUInt64(lists, o + 0x10);
                int n = BitConverter.ToInt32(lists, o + 0x18);
                if (n <= 0 || n > 512) continue;
                var al = Read(arr, n * 0x1C0);
                if (al == null) continue;
                for (int v = 0; v < n; v++)
                {
                    int a = v * 0x1C0;
                    Console.WriteLine("{0}\t{1:x16}\t{2}\t{3:x16}\t{4:x16}\t{5:x16}\t{6:x16}", zone, name, v, BitConverter.ToUInt64(al, a + 0x20),
                        BitConverter.ToUInt64(al, a + 0x48), BitConverter.ToUInt64(al, a + 0x68), BitConverter.ToUInt64(al, a + 0x88));
                    rows++;
                }
            }
        }
        Console.Error.WriteLine("{0} banks, {1} alias variants", banks, rows);
        return 0;
    }
}
