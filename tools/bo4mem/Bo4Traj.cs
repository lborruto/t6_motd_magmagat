// Watches Black Ops 4 for projectile trajectories: { type (small), time, duration, vec3 base, vec3 delta } where the
// delta is a launch velocity (300..10000 units/s). Polls the exe's writable memory for <seconds> and prints each new
// trajectory once, with the velocity's length, its horizontal part and its vertical part.
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:Bo4Traj.exe Bo4Traj.cs
//   run:   Bo4Traj.exe <seconds> [--heap]   (--heap: the private heap regions up to 256 MB each instead of the exe)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

static class Bo4Traj
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MBI info, IntPtr len);

    [StructLayout(LayoutKind.Sequential)]
    struct MBI { public ulong BaseAddress, AllocationBase; public uint AllocationProtect, Pad0; public ulong RegionSize; public uint State, Protect, Type, Pad1; }

    static bool Pos(float f) { return !float.IsNaN(f) && Math.Abs(f) < 65536; }

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        var proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress, end = b + (ulong)p[0].MainModule.ModuleMemorySize;
        // the exe's writable regions (g_entities and the client entities are static arrays)
        var regions = new List<KeyValuePair<ulong, ulong>>();
        MBI m;
        bool heap = args.Length > 1 && args[1] == "--heap";
        for (ulong a = heap ? 0x10000UL : b; (heap || a < end) && VirtualQueryEx(proc, (IntPtr)(long)a, out m, (IntPtr)Marshal.SizeOf(typeof(MBI))) != IntPtr.Zero; a = m.BaseAddress + m.RegionSize)
            if (m.State == 0x1000 && (m.Protect & 0x100) == 0 && (m.Protect & 0xCC) != 0 && (!heap || (m.Type == 0x20000 && m.RegionSize <= 0x10000000))) regions.Add(new KeyValuePair<ulong, ulong>(m.BaseAddress, m.RegionSize));
        ulong total = 0; foreach (var r in regions) total += r.Value;
        Console.WriteLine("watching {0} writable regions, {1} MB, for {2} s", regions.Count, total >> 20, args[0]);
        var seen = new HashSet<string>();
        var sw = Stopwatch.StartNew();
        bool first = true;
        while (sw.Elapsed.TotalSeconds < double.Parse(args[0]))
        {
            foreach (var r in regions)
                for (ulong at = r.Key; at < r.Key + r.Value; at += 0x400000)
                {
                    int len = (int)Math.Min(0x400000, r.Key + r.Value - at);
                    var d = new byte[len];
                    IntPtr got;
                    if (!ReadProcessMemory(proc, (IntPtr)(long)at, d, (IntPtr)len, out got)) continue;
                    for (int o = 0; o + 36 <= len; o += 4)
                    {
                        uint type = BitConverter.ToUInt32(d, o);
                        if (type == 0 || type > 16) continue;
                        int time = BitConverter.ToInt32(d, o + 4), dur = BitConverter.ToInt32(d, o + 8);
                        if (time <= 1000 || dur < 0 || dur > 100000) continue;
                        float x = BitConverter.ToSingle(d, o + 12), y = BitConverter.ToSingle(d, o + 16), z = BitConverter.ToSingle(d, o + 20);
                        float vx = BitConverter.ToSingle(d, o + 24), vy = BitConverter.ToSingle(d, o + 28), vz = BitConverter.ToSingle(d, o + 32);
                        if (!Pos(x) || !Pos(y) || !Pos(z) || Math.Abs(x) < 1 || Math.Abs(y) < 1 || Math.Abs(z) < 1 || Math.Abs(vx) < 1 || Math.Abs(vy) < 1 || !Pos(vx) || !Pos(vy) || !Pos(vz)) continue;
                        double h = Math.Sqrt(vx * vx + vy * vy), n = Math.Sqrt(h * h + vz * vz);
                        if (n < 300 || n > 10000) continue;
                        string key = string.Format("{0:X}|{1}|{2}|{3}", at + (ulong)o, vx, vy, vz);
                        if (!seen.Add(key)) continue;
                        Console.WriteLine("{0}{1,6:F1}s exe+{2:X} type {3} time {4} dur {5} base ({6:F0} {7:F0} {8:F0}) vel ({9:F1} {10:F1} {11:F1}) |v| {12:F1} horiz {13:F1} up {14:F1}",
                            first ? "[before] " : "", sw.Elapsed.TotalSeconds, at + (ulong)o - b, type, time, dur, x, y, z, vx, vy, vz, n, h, vz);
                    }
                }
            first = false;
        }
        return 0;
    }
}
