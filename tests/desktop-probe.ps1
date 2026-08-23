<#
    Reports the visible, titled top-level windows whose title contains -Match,
    and whether each is on the virtual desktop currently in view.

    Used by tests/windows.sh to check that a URL landed on the desktop you are
    looking at, which is the one thing about #13 that cannot be asserted from a
    Linux runner.
#>

param([Parameter(Mandatory = $true)][string]$Match)

Add-Type -TypeDefinition @'
using System;using System.Collections.Generic;using System.Runtime.InteropServices;using System.Text;
public static class Probe {
  [ComImport, Guid("a5cd92ff-29be-454c-8d04-d82879fb3f1b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  private interface IVirtualDesktopManager {
    [PreserveSig] int IsWindowOnCurrentVirtualDesktop(IntPtr w, out int onCurrent);
    [PreserveSig] int GetWindowDesktopId(IntPtr w, out Guid d);
    [PreserveSig] int MoveWindowToDesktop(IntPtr w, ref Guid d);
  }
  private delegate bool EnumWindowsProc(IntPtr w, IntPtr p);
  [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc cb, IntPtr p);
  [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr w);
  [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr w);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowTextW(IntPtr w, StringBuilder s, int n);
  private static IVirtualDesktopManager _m;
  private static IVirtualDesktopManager M {
    get { if (_m == null) _m = (IVirtualDesktopManager)Activator.CreateInstance(
            Type.GetTypeFromCLSID(new Guid("aa509086-5ca9-4c25-8f95-589d3c07b48a"))); return _m; } }
  public static List<string> Find(string match) {
    var rows = new List<string>();
    EnumWindows((w, p) => {
      if (!IsWindowVisible(w) || GetWindowTextLength(w) == 0) return true;
      var sb = new StringBuilder(512); GetWindowTextW(w, sb, 512);
      string title = sb.ToString();
      if (title.IndexOf(match, StringComparison.OrdinalIgnoreCase) < 0) return true;
      int onCurrent;
      // A failed call is reported as "?" rather than guessed at.
      string state = M.IsWindowOnCurrentVirtualDesktop(w, out onCurrent) != 0
        ? "?" : (onCurrent != 0 ? "here" : "elsewhere");
      rows.Add(state + "\t" + title);
      return true;
    }, IntPtr.Zero);
    return rows;
  }
}
'@

[Probe]::Find($Match)
