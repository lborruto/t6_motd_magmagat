// Finds code in BlackOps4.exe that reads [reg+<disp>] within a few instructions after loading [reg+<after>]
// (a field of a sub-struct reached through a pointer), and prints the context. Iced.dll as Bo4Dis.
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /r:Iced.dll /out:Bo4Xref.exe Bo4Xref.cs
//   Bo4Xref.exe <hexdisp> <hexafter> <hexfrom> <hexto>     image offsets
//   Bo4Xref.exe --calls <hexoff> <hexfrom> <hexto>         calls and jumps to BlackOps4.exe+<hexoff>
//   Bo4Xref.exe --cvt <hexafter> <hexfrom> <hexto>         int fields converted to float through [reg+<after>]
//   (hexafter FFFF: any read of [reg+<disp>])
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Iced.Intel;

static class Bo4Xref
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    static int Main(string[] args)
    {
        var p = Process.GetProcessesByName("BlackOps4");
        if (p.Length == 0) { Console.Error.WriteLine("BlackOps4 is not running"); return 1; }
        var proc = OpenProcess(0x0410, false, p[0].Id);
        ulong b = (ulong)(long)p[0].MainModule.BaseAddress;
        bool calls = args[0] == "--calls";
        bool cvt = args[0] == "--cvt";
        if (cvt) args = new[] { "0", args[1], args[2], args[3] };
        var seen = new Dictionary<ulong, List<ulong>>();
        if (calls) args = new[] { args[1], "0", args[2], args[3] };
        ulong disp = Convert.ToUInt64(args[0], 16), after = Convert.ToUInt64(args[1], 16);
        long from = Convert.ToInt64(args[2], 16), to = Convert.ToInt64(args[3], 16);
        const int CH = 0x100000;
        int hits = 0;
        for (long off = from; off < to; off += CH)
        {
            var code = new byte[CH + 64];
            IntPtr got;
            if (!ReadProcessMemory(proc, (IntPtr)(long)(b + (ulong)off), code, (IntPtr)code.Length, out got)) continue;
            var dec = Decoder.Create(64, new ByteArrayCodeReader(code));
            dec.IP = b + (ulong)off;
            var last = new Queue<Instruction>();
            while (dec.IP < b + (ulong)off + CH)
            {
                var ins = dec.Decode();
                if (ins.IsInvalid) { last.Clear(); continue; }
                last.Enqueue(ins);
                if (last.Count > 8) last.Dequeue();
                if (calls) { if ((ins.Mnemonic == Mnemonic.Call || ins.Mnemonic == Mnemonic.Jmp) && ins.Op0Kind == OpKind.NearBranch64 && ins.NearBranch64 == b + disp) { hits++; Console.WriteLine("--"); foreach (var q in last) Console.WriteLine("exe+{0:X} {1}", q.IP - b, q); } continue; }
                if (cvt) { if (ins.Mnemonic == Mnemonic.Cvtsi2ss && ins.Op1Kind == OpKind.Memory && ins.MemoryBase != Register.RIP) { foreach (var q in last) if (q.MemoryDisplacement64 == after && q.Op0Kind == OpKind.Register && q.Op0Register == ins.MemoryBase) { if (!seen.ContainsKey(ins.MemoryDisplacement64)) seen[ins.MemoryDisplacement64] = new List<ulong>(); seen[ins.MemoryDisplacement64].Add(ins.IP - b); break; } } continue; }
                if (ins.MemoryDisplacement64 != disp || ins.MemoryBase == Register.None || ins.MemoryBase == Register.RIP) continue;
                bool ok = false;
                if (after == 0xFFFF) ok = true;
                foreach (var q in last) if (q.MemoryDisplacement64 == after && q.Op0Kind == OpKind.Register && q.Op0Register == ins.MemoryBase) ok = true;
                if (!ok) continue;
                hits++;
                Console.WriteLine("--");
                foreach (var q in last) Console.WriteLine("exe+{0:X} {1}", q.IP - b, q);
            }
        }
        foreach (var kv in seen) Console.WriteLine("+{0:X}: {1}", kv.Key, string.Join(" ", kv.Value.ConvertAll(x => x.ToString("X")).ToArray()));
        Console.WriteLine("{0} hits", hits);
        return 0;
    }
}
