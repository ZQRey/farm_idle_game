param(
    [int]$ProcessId = 0,
    [switch]$SetDesktopBottom = $true,
    [switch]$SetClickThrough = $true
)

$source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class Win32Helper {
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_LAYERED = 0x00080000;
    public const int WS_EX_NOACTIVATE = 0x08000000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;

    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public static long GetWindowLong(IntPtr hWnd, int nIndex) {
        if (IntPtr.Size == 8) {
            return GetWindowLongPtr64(hWnd, nIndex).ToInt64();
        } else {
            return GetWindowLong32(hWnd, nIndex);
        }
    }

    public static void SetWindowLong(IntPtr hWnd, int nIndex, long dwNewLong) {
        if (IntPtr.Size == 8) {
            SetWindowLongPtr64(hWnd, nIndex, new IntPtr(dwNewLong));
        } else {
            SetWindowLong32(hWnd, nIndex, (int)dwNewLong);
        }
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp

if ($ProcessId -eq 0) {
    $ProcessId = [System.Diagnostics.Process]::GetCurrentProcess().Id
}

$matchingWindows = New-Object System.Collections.Generic.List[IntPtr]

# Ожидание появления окна (до 3 сек при запуске Godot)
for ($retry = 0; $retry -lt 30; $retry++) {
    $matchingWindows.Clear()
    [void][Win32Helper]::EnumWindows({
        param($hwnd, $lParam)
        [uint32]$pId = 0
        [Win32Helper]::GetWindowThreadProcessId($hwnd, [ref]$pId)
        if ($pId -eq $ProcessId) {
            $sb = New-Object System.Text.StringBuilder 256
            [Win32Helper]::GetWindowText($hwnd, $sb, $sb.Capacity)
            $title = $sb.ToString()
            # Игнорируем окно Штаба фермы, настраиваем только главное окно полосы компаньона
            if ($title -notmatch "Штаб") {
                $matchingWindows.Add($hwnd)
            }
        }
        return $true
    }, [IntPtr]::Zero)

    if ($matchingWindows.Count -gt 0) {
        break
    }
    Start-Sleep -Milliseconds 100
}

foreach ($hwnd in $matchingWindows) {
    $currentExStyle = [Win32Helper]::GetWindowLong($hwnd, [Win32Helper]::GWL_EXSTYLE)
    $newExStyle = $currentExStyle

    if ($SetClickThrough) {
        # WS_EX_TRANSPARENT: клики мыши проходят насквозь на ярлыки и рабочий стол Windows
        $newExStyle = $newExStyle -bor [Win32Helper]::WS_EX_TRANSPARENT
        $newExStyle = $newExStyle -bor [Win32Helper]::WS_EX_NOACTIVATE
    }

    [Win32Helper]::SetWindowLong($hwnd, [Win32Helper]::GWL_EXSTYLE, $newExStyle)

    if ($SetDesktopBottom) {
        # HWND_BOTTOM: окно помещается в самый низ Z-order (на рабочий стол позади всех обычных окон)
        [Win32Helper]::SetWindowPos($hwnd, [Win32Helper]::HWND_BOTTOM, 0, 0, 0, 0, 
            [Win32Helper]::SWP_NOMOVE -bor [Win32Helper]::SWP_NOSIZE -bor [Win32Helper]::SWP_NOACTIVATE -bor [Win32Helper]::SWP_SHOWWINDOW)
    }
    Write-Output "Configured desktop background companion window $hwnd for PID $ProcessId"
}
