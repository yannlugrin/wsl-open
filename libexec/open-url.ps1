<#
    Open a URL in a browser window on the virtual desktop currently in view.

    Windows hands a URL to the already running browser, which opens it in
    whichever of its windows was last active -- on whatever virtual desktop that
    window sits. So the tab either lands out of sight, or Windows drags the view
    over to the other desktop to follow it.

    A browser reaches for its last active window, and activating one is all it
    takes to make it that. So: raise a window that is already on this desktop,
    then hand over the URL. With no window here to raise, open a new one, which
    Windows always places on the desktop in view.

    Exits non-zero when it cannot do better than the shell would -- unknown
    scheme, or a browser it has no window flag for -- so the caller can fall
    back to the plain handler.
#>

param(
  [Parameter(Mandatory = $true)][string]$Url
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Win {
    // The public, documented half of the virtual desktop API. The interface
    // that can enumerate and switch desktops is undocumented and its GUID moves
    // between Windows builds; this one has been stable since Windows 10 and
    // answers the only question asked here.
    [ComImport, Guid("a5cd92ff-29be-454c-8d04-d82879fb3f1b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IVirtualDesktopManager {
        [PreserveSig] int IsWindowOnCurrentVirtualDesktop(IntPtr window, out int onCurrent);
        [PreserveSig] int GetWindowDesktopId(IntPtr window, out Guid desktop);
        [PreserveSig] int MoveWindowToDesktop(IntPtr window, ref Guid desktop);
    }

    private delegate bool EnumWindowsProc(IntPtr window, IntPtr param);

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr window);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("Shlwapi.dll", CharSet = CharSet.Unicode)]
    private static extern uint AssocQueryString(int flags, int str, string assoc, string extra, StringBuilder output, ref uint size);

    private static IVirtualDesktopManager _manager;
    private static IVirtualDesktopManager Manager {
        get {
            if (_manager == null) {
                Type type = Type.GetTypeFromCLSID(new Guid("aa509086-5ca9-4c25-8f95-589d3c07b48a"));
                _manager = (IVirtualDesktopManager)Activator.CreateInstance(type);
            }
            return _manager;
        }
    }

    // The handler the shell would pick for a scheme. Asking the shell rather
    // than reading the UserChoice registry key, which on this machine names
    // Edge for http while the shell launches Chrome.
    public static string BrowserFor(string scheme) {
        var buffer = new StringBuilder(1024);
        uint size = 1024;
        const int ASSOCSTR_EXECUTABLE = 2;
        return AssocQueryString(0, ASSOCSTR_EXECUTABLE, scheme, "open", buffer, ref size) == 0
            ? buffer.ToString()
            : null;
    }

    // Top-level windows belonging to the given processes, topmost first.
    // Minimised windows count, and so do windows on other desktops: both are
    // still "visible" as far as Win32 is concerned, which is exactly why the
    // desktop has to be asked about separately.
    public static List<IntPtr> WindowsOf(uint[] pids) {
        var wanted = new HashSet<uint>(pids);
        var windows = new List<IntPtr>();

        EnumWindows((window, param) => {
            // A browser keeps a handful of invisible, title-less helper windows
            // around; only the ones a person could click on are candidates.
            if (!IsWindowVisible(window) || GetWindowTextLength(window) == 0) return true;

            uint pid;
            GetWindowThreadProcessId(window, out pid);
            if (wanted.Contains(pid)) windows.Add(window);

            return true;
        }, IntPtr.Zero);

        return windows;
    }

    public static bool OnCurrentDesktop(IntPtr window) {
        int onCurrent;
        // A failed call means "no idea", which must not read as "yes": opening
        // a new window is the safe answer, a tab on another desktop is not.
        return Manager.IsWindowOnCurrentVirtualDesktop(window, out onCurrent) == 0 && onCurrent != 0;
    }

    public static bool Raise(IntPtr window) {
        const int SW_RESTORE = 9;
        if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
        return SetForegroundWindow(window);
    }
}
'@

$browser = [Win]::BrowserFor(($Url -split ':')[0])
if (-not $browser -or -not (Test-Path -LiteralPath $browser)) {
  exit 1
}

# Reuse only works for a browser that takes a URL on the command line and hands
# it to the instance already running. Anything else is left to the shell.
$newWindow = switch -Regex ([IO.Path]::GetFileName($browser)) {
  '^(chrome|msedge|brave|vivaldi|opera|thorium)\.exe$' { '--new-window' }
  '^(firefox|librewolf|waterfox)\.exe$'               { '-new-window' }
  default { exit 1 }
}

$name = [IO.Path]::GetFileNameWithoutExtension($browser)
$pids = @(Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })

$here = @([Win]::WindowsOf($pids)) |
  Where-Object { [Win]::OnCurrentDesktop($_) } |
  Select-Object -First 1

# The URL goes after `--` so that one starting with a dash cannot be read as a
# flag, and quoted so that `&` reaches the browser instead of the command line.
if ($here -and [Win]::Raise($here)) {
  $arguments = "-- `"$Url`""
} else {
  $arguments = "$newWindow -- `"$Url`""
}

Start-Process -FilePath $browser -ArgumentList $arguments
