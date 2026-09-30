// Bo3Snapshot: copies Black Ops III's loaded effects out of the running game, for tools/bo3_fx.pl to turn into T6
// effects. BO3 has to be running with the map loaded (the BO3 remaster's "MOB OF THE DEAD", solo is enough).
//
// It finds the asset pools the way HydraX does (Scobalula, github.com/Scobalula/HydraX: the Steam exe's signature),
// walks the fx pool and writes every live FxEffectDef with all the memory reachable from it through pointers
// (elements, samples, materials, their textures and images, names): a compiled effect points at its materials by
// address, and only the running game resolves them.
//
//   build: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:Bo3Snapshot.exe Bo3Snapshot.cs
//   run:   Bo3Snapshot.exe <out.bin> [pool index, default 38 = fx] [depth, default 5]
//          Bo3Snapshot.exe --scripts <out dir> [name filter]   (the loaded compiled scripts)
//
// out.bin: "BO3SNAP1", u32 asset count, per asset (u64 header address, u32 header size, u16 name length, name), then
// the memory: records of (u64 address, u32 length, bytes) until the end.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

static class Bo3Snapshot
{
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MBI info, IntPtr len);

    [StructLayout(LayoutKind.Sequential)]
    struct MBI
    {
        public ulong BaseAddress, AllocationBase;
        public uint AllocationProtect, Pad0;
        public ulong RegionSize;
        public uint State, Protect, Type, Pad1;
    }

    static IntPtr proc;
    static readonly Dictionary<ulong, byte[]> regions = new Dictionary<ulong, byte[]>();
    static readonly Dictionary<ulong, ulong> readableEnd = new Dictionary<ulong, ulong>();
    static long total;
    const long TotalCap = 768L << 20;

    static byte[] Read(ulong addr, int len)
    {
        var buf = new byte[len];
        IntPtr got;
        if (!ReadProcessMemory(proc, (IntPtr)(long)addr, buf, (IntPtr)len, out got) || (long)got != len)
            return null;
        return buf;
    }

    // the regions already queried, by base: a crawl asks about the same few heaps millions of times
    static readonly List<ulong[]> known = new List<ulong[]>();

    // the end of the readable committed region holding addr, 0 when unreadable
    static ulong ReadableUntil(ulong addr)
    {
        int lo = 0, hi = known.Count - 1;
        while (lo <= hi)
        {
            int mid = (lo + hi) / 2;
            if (addr < known[mid][0]) hi = mid - 1;
            else if (addr >= known[mid][1]) lo = mid + 1;
            else return known[mid][2];
        }
        ulong rbase, rend;
        ulong until = QueryReadableUntil(addr, out rbase, out rend);
        known.Insert(lo, new[] { rbase, rend, until });
        return until;
    }

    static ulong QueryReadableUntil(ulong addr, out ulong rbase, out ulong rend)
    {
        MBI m;
        rbase = addr & ~0xFFFUL;
        rend = rbase + 0x1000;
        if (VirtualQueryEx(proc, (IntPtr)(long)addr, out m, (IntPtr)Marshal.SizeOf(typeof(MBI))) == IntPtr.Zero)
            return 0;
        rbase = m.BaseAddress;
        rend = m.BaseAddress + m.RegionSize;
        const uint MEM_COMMIT = 0x1000, PAGE_NOACCESS = 0x01, PAGE_GUARD = 0x100;
        if (m.State != MEM_COMMIT || (m.Protect & PAGE_NOACCESS) != 0 || (m.Protect & PAGE_GUARD) != 0)
            return 0;
        return m.BaseAddress + m.RegionSize;
    }

    static bool LooksLikePointer(ulong v)
    {
        return v >= 0x10000 && v < 0x7FFFFFFFFFFF && ReadableUntil(v) != 0;
    }

    static string CString(ulong addr)
    {
        var b = Read(addr, 256);
        if (b == null) return null;
        int n = Array.IndexOf(b, (byte)0);
        if (n <= 0) return null;
        for (int i = 0; i < n; i++)
            if (b[i] < 0x20 || b[i] > 0x7e) return null;
        return Encoding.ASCII.GetString(b, 0, n);
    }

    // captures len bytes at addr and, depth permitting, every pointer inside them
    static void Capture(ulong addr, int len, int depth)
    {
        byte[] had;
        if (total > TotalCap || (regions.TryGetValue(addr, out had) && had.Length >= len))
            return;
        ulong end = ReadableUntil(addr);
        if (end == 0) return;
        if (addr + (ulong)len > end) len = (int)(end - addr);
        if (len <= 0) return;
        var b = Read(addr, len);
        if (b == null) return;
        regions[addr] = b;
        total += len;
        if (depth <= 0) return;
        for (int o = 0; o + 8 <= b.Length; o += 8)
        {
            ulong v = BitConverter.ToUInt64(b, o);
            if (LooksLikePointer(v))
                Capture(v, 1024, depth - 1);
        }
    }

    // an element's arrays at their real sizes (the generic capture takes 1 KB): velocity samples (+208, 96 bytes,
    // count at +202), visual samples (+224, 80 bytes, count at +205), the visual array (+240, count at +201) and a
    // trail's vertices and indices (+488: FxTrailDef, vertCount at +20 / verts at +24, indCount at +32 / inds at +40)
    static void CaptureElements(ulong elems, int count, int depth)
    {
        for (int i = 0; i < count; i++)
        {
            var e = Read(elems + (ulong)(i * 608), 608);
            if (e == null) continue;
            int type = e[200], visuals = e[201], nvel = e[202], nvis = e[205];
            CaptureArray(BitConverter.ToUInt64(e, 208), (nvel + 1) * 96, depth);
            CaptureArray(BitConverter.ToUInt64(e, 224), (nvis + 1) * 80, depth);
            if (visuals > 1) CaptureArray(BitConverter.ToUInt64(e, 240), visuals * 8, depth);
            ulong vp = BitConverter.ToUInt64(e, 240);
            if (visuals == 1) CaptureMaterial(vp);
            else if (visuals > 1 && LooksLikePointer(vp))
            {
                var arr = Read(vp, visuals * 8);
                if (arr != null)
                    for (int k = 0; k < visuals; k++) CaptureMaterial(BitConverter.ToUInt64(arr, k * 8));
            }
            if (type == 5)
            {
                ulong trail = BitConverter.ToUInt64(e, 488);
                var t = LooksLikePointer(trail) ? Read(trail, 48) : null;
                if (t != null)
                {
                    CaptureArray(BitConverter.ToUInt64(t, 24), BitConverter.ToInt32(t, 20) * 20, depth);
                    CaptureArray(BitConverter.ToUInt64(t, 40), BitConverter.ToInt32(t, 32) * 2, depth);
                }
            }
        }
    }

    // a material's techset and image names, however deep they sit (HydraX's layout: images at +624 / +640, 32-byte
    // entries, an image's name pointer at +0xF8)
    static void CaptureMaterial(ulong m)
    {
        if (!LooksLikePointer(m)) return;
        var b = Read(m, 656);
        if (b == null) return;
        Capture(m, 656, 1);
        Capture(BitConverter.ToUInt64(b, 632), 64, 1);
        int count = b[624];
        ulong table = BitConverter.ToUInt64(b, 640);
        if (count == 0 || count > 32 || !LooksLikePointer(table)) return;
        var t = Read(table, count * 32);
        if (t == null) return;
        Capture(table, count * 32, 0);
        for (int k = 0; k < count; k++)
        {
            ulong img = BitConverter.ToUInt64(t, k * 32);
            if (!LooksLikePointer(img)) continue;
            var ib = Read(img, 0x100);
            if (ib == null) continue;
            Capture(img, 0x100, 0);
            ulong name = BitConverter.ToUInt64(ib, 0xF8);
            if (LooksLikePointer(name)) Capture(name, 256, 0);
        }
    }

    static void CaptureArray(ulong p, int len, int depth)
    {
        if (len > 0 && len < (1 << 20) && LooksLikePointer(p))
            Capture(p, len, depth);
    }

    // --scripts: the compiled scripts (the scriptparsetree pool: name, size, data; HydraX's layout) whose name holds the
    // filter, written as they sit in memory (BO3's compiled GSC / CSC)
    static int DumpScripts(ulong poolPtr, int assetSize, int poolSize, string outDir, string filter)
    {
        int n = 0;
        ulong poolEnd = poolPtr + (ulong)poolSize * (ulong)assetSize;
        for (int i = 0; i < poolSize; i++)
        {
            var h = Read(poolPtr + (ulong)i * (ulong)assetSize, 24);
            if (h == null) continue;
            ulong namePtr = BitConverter.ToUInt64(h, 0);
            if (namePtr == 0 || (namePtr >= poolPtr && namePtr < poolEnd)) continue;
            string name = CString(namePtr);
            if (name == null || name.IndexOf(filter, StringComparison.OrdinalIgnoreCase) < 0) continue;
            long size = BitConverter.ToInt64(h, 8);
            ulong data = BitConverter.ToUInt64(h, 16);
            if (size <= 0 || size > (64 << 20)) continue;
            var b = Read(data, (int)size);
            if (b == null) continue;
            string path = Path.Combine(outDir, name.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllBytes(path, b);
            Console.WriteLine("Bo3Snapshot: {0} ({1} bytes)", name, size);
            n++;
        }
        Console.WriteLine("Bo3Snapshot: {0} scripts -> {1}", n, outDir);
        return n > 0 ? 0 : 1;
    }

    static long FindPattern(byte[] image, int?[] pat)
    {
        for (int i = 0; i + pat.Length <= image.Length; i++)
        {
            int k = 0;
            while (k < pat.Length && (pat[k] == null || image[i + k] == pat[k])) k++;
            if (k == pat.Length) return i;
        }
        return -1;
    }

    static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("usage: Bo3Snapshot.exe <out.bin> [pool index] [depth] | --scripts <out dir> [name filter]");
            return 2;
        }
        bool scripts = args[0] == "--scripts";
        int poolIndex = scripts ? 54 : args.Length > 1 ? int.Parse(args[1]) : 38;
        int depth = !scripts && args.Length > 2 ? int.Parse(args[2]) : 5;

        var ps = Process.GetProcessesByName("BlackOps3");
        if (ps.Length == 0)
        {
            Console.Error.WriteLine("Bo3Snapshot: Black Ops III is not running (start it and load the map first)");
            return 1;
        }
        var p = ps[0];
        proc = OpenProcess(0x0400 | 0x0010, false, p.Id);
        if (proc == IntPtr.Zero)
        {
            Console.Error.WriteLine("Bo3Snapshot: cannot open BlackOps3.exe (run as the same user, not elevated game)");
            return 1;
        }
        ulong baseAddr = (ulong)(long)p.MainModule.BaseAddress;
        int size = p.MainModule.ModuleMemorySize;

        // the module image, readable pages only
        var image = new byte[size];
        for (int off = 0; off < size; off += 0x1000)
        {
            var page = Read(baseAddr + (ulong)off, Math.Min(0x1000, size - off));
            if (page != null) Buffer.BlockCopy(page, 0, image, off, page.Length);
        }
        // HydraX: 63 C1 48 8D 05 ?? ?? ?? ?? 49 C1 E0 ?? 4C 03 C0, pools = rel32 at +5 from +9
        var sig = new int?[] { 0x63, 0xC1, 0x48, 0x8D, 0x05, null, null, null, null, 0x49, 0xC1, 0xE0, null, 0x4C, 0x03, 0xC0 };
        long hit = FindPattern(image, sig);
        if (hit < 0)
        {
            Console.Error.WriteLine("Bo3Snapshot: the asset pool signature is not in this BlackOps3.exe (not the Steam build?)");
            return 1;
        }
        ulong pools = baseAddr + (ulong)hit + 9 + (ulong)(long)BitConverter.ToInt32(image, (int)hit + 5);
        var info = Read(pools + (ulong)poolIndex * 32, 32);
        ulong poolPtr = BitConverter.ToUInt64(info, 0);
        int assetSize = BitConverter.ToInt32(info, 8);
        int poolSize = BitConverter.ToInt32(info, 12);
        Console.WriteLine("Bo3Snapshot: pools at 0x{0:X}, pool {1}: {2} slots of {3} bytes at 0x{4:X}", pools, poolIndex, poolSize, assetSize, poolPtr);
        if (scripts)
            return DumpScripts(poolPtr, assetSize, poolSize, args.Length > 1 ? args[1] : "scripts", args.Length > 2 ? args[2] : "");

        var assets = new List<Tuple<ulong, string>>();
        ulong poolEnd = poolPtr + (ulong)poolSize * (ulong)assetSize;
        for (int i = 0; i < poolSize; i++)
        {
            ulong header = poolPtr + (ulong)i * (ulong)assetSize;
            var h = Read(header, 8);
            if (h == null) continue;
            ulong namePtr = BitConverter.ToUInt64(h, 0);
            if (namePtr == 0 || (namePtr >= poolPtr && namePtr < poolEnd)) continue; // a free slot
            string name = CString(namePtr);
            if (name == null) continue;
            assets.Add(Tuple.Create(header, name));
            // the elements first, whole: the header gives their count (T7 FxEffectDef: counts at +12, elemDefs at +32, 608 bytes each)
            var hd = Read(header, assetSize);
            if (hd != null && assetSize >= 40)
            {
                int count = BitConverter.ToInt16(hd, 12) + BitConverter.ToInt16(hd, 14) + BitConverter.ToInt16(hd, 16);
                ulong elems = BitConverter.ToUInt64(hd, 32);
                if (count > 0 && count < 512 && LooksLikePointer(elems))
                {
                    Capture(elems, count * 608, depth - 1);
                    CaptureElements(elems, count, depth - 2);
                }
            }
            Capture(header, assetSize, depth);
            if (assets.Count % 100 == 0)
                Console.WriteLine("Bo3Snapshot: {0} effects, {1} MB", assets.Count, total >> 20);
        }

        using (var w = new BinaryWriter(File.Create(args[0])))
        {
            w.Write(Encoding.ASCII.GetBytes("BO3SNAP1"));
            w.Write((uint)assets.Count);
            foreach (var a in assets)
            {
                var nb = Encoding.ASCII.GetBytes(a.Item2);
                w.Write(a.Item1);
                w.Write((uint)assetSize);
                w.Write((ushort)nb.Length);
                w.Write(nb);
            }
            foreach (var r in regions)
            {
                w.Write(r.Key);
                w.Write((uint)r.Value.Length);
                w.Write(r.Value);
            }
        }
        Console.WriteLine("Bo3Snapshot: {0} assets, {1} regions, {2} MB -> {3}", assets.Count, regions.Count, total >> 20, args[0]);
        return 0;
    }
}
