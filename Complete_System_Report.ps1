# Create a folder for reports if it doesn't exist
$reportFolder = "C:\Reports"
if (-not (Test-Path -Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory
}

# Define file path
$reportFile = "$reportFolder\Complete_System_Report.html"

# Collect system health info
$sysInfo = New-Object PSObject -property @{
    "OS Version" = (Get-CimInstance Win32_OperatingSystem).Caption
    "CPU" = (Get-CimInstance Win32_Processor).Name
    "Total RAM" = "{0} GB" -f [math]::round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 2)
    "Free RAM" = "{0} GB" -f [math]::round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    "Total Disk Space" = "{0} GB" -f [math]::round((Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3").Size / 1GB, 2)
    "Free Disk Space" = "{0} GB" -f [math]::round((Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3").FreeSpace / 1GB, 2)
    "CPU Usage" = (Get-WmiObject -Query "SELECT * FROM Win32_Processor").LoadPercentage
}

# Collect event log info (last 7 days)
$startDate = (Get-Date).AddDays(-7)
$endDate = Get-Date
$logs = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$startDate; EndTime=$endDate} | Select-Object TimeCreated, Id, LevelDisplayName, Message

# Collect disk space info
$diskInfo = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, @{Name="Size(GB)";Expression={[math]::round($_.Size / 1GB, 2)}}, @{Name="Free Space(GB)";Expression={[math]::round($_.FreeSpace / 1GB, 2)}}, @{Name="Used Space(GB)";Expression={[math]::round(($_.Size - $_.FreeSpace) / 1GB, 2)}}

# Collect AD users info
$adUsers = Get-ADUser -Filter * -Property DisplayName, Enabled, LastLogonDate, LastBadPasswordAttempt | Select-Object DisplayName, Enabled, LastLogonDate, LastBadPasswordAttempt

# Collect installed software info
$software = Get-WmiObject -Class Win32_Product | Select-Object Name, Version, InstallDate

# Collect network adapter info
$networkAdapters = Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed

# Collect security updates info
$updates = Get-HotFix | Select-Object Description, HotFixID, InstalledOn

# Collect user login events (last 7 days)
$loginEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; StartTime=$startDate; EndTime=$endDate} | Where-Object {$_.Id -eq 4624} | Select-Object TimeCreated, Message

# Build HTML report content
$htmlContent = @"
<html>
<head>
    <style>
        body {font-family: Arial; font-size: 12pt;}
        table {border-collapse: collapse; width: 100%;}
        th, td {border: 1px solid black; padding: 5px; text-align: left;}
    </style>
</head>
<body>
    <h1>Complete System Report</h1>

    <h2>System Health</h2>
    <table>
        <tr><th>Property</th><th>Value</th></tr>
        <tr><td>OS Version</td><td>$($sysInfo.'OS Version')</td></tr>
        <tr><td>CPU</td><td>$($sysInfo.'CPU')</td></tr>
        <tr><td>Total RAM</td><td>$($sysInfo.'Total RAM')</td></tr>
        <tr><td>Free RAM</td><td>$($sysInfo.'Free RAM')</td></tr>
        <tr><td>Total Disk Space</td><td>$($sysInfo.'Total Disk Space')</td></tr>
        <tr><td>Free Disk Space</td><td>$($sysInfo.'Free Disk Space')</td></tr>
        <tr><td>CPU Usage</td><td>$($sysInfo.'CPU Usage')%</td></tr>
    </table>

    <h2>Event Logs (Last 7 Days)</h2>
    <table>
        <tr><th>Time</th><th>Event ID</th><th>Level</th><th>Message</th></tr>
        $($logs | ForEach-Object { "<tr><td>$($_.TimeCreated)</td><td>$($_.Id)</td><td>$($_.LevelDisplayName)</td><td>$($_.Message)</td></tr>" } | Out-String)
    </table>

    <h2>Disk Space</h2>
    <table>
        <tr><th>Drive</th><th>Size (GB)</th><th>Free Space (GB)</th><th>Used Space (GB)</th></tr>
        $($diskInfo | ForEach-Object { "<tr><td>$($_.DeviceID)</td><td>$($_.'Size(GB)')</td><td>$($_.'Free Space(GB)')</td><td>$($_.'Used Space(GB)')</td></tr>" } | Out-String)
    </table>

    <h2>Active Directory Users</h2>
    <table>
        <tr><th>Name</th><th>Enabled</th><th>Last Logon Date</th><th>Last Bad Password Attempt</th></tr>
        $($adUsers | ForEach-Object { "<tr><td>$($_.DisplayName)</td><td>$($_.Enabled)</td><td>$($_.LastLogonDate)</td><td>$($_.LastBadPasswordAttempt)</td></tr>" } | Out-String)
    </table>

    <h2>Installed Software</h2>
    <table>
        <tr><th>Software Name</th><th>Version</th><th>Install Date</th></tr>
        $($software | ForEach-Object { "<tr><td>$($_.Name)</td><td>$($_.Version)</td><td>$($_.InstallDate)</td></tr>" } | Out-String)
    </table>

    <h2>Network Adapters</h2>
    <table>
        <tr><th>Adapter Name</th><th>Status</th><th>MAC Address</th><th>Link Speed</th></tr>
        $($networkAdapters | ForEach-Object { "<tr><td>$($_.Name)</td><td>$($_.Status)</td><td>$($_.MacAddress)</td><td>$($_.LinkSpeed)</td></tr>" } | Out-String)
    </table>

    <h2>Security Updates</h2>
    <table>
        <tr><th>Description</th><th>HotFix ID</th><th>Installed On</th></tr>
        $($updates | ForEach-Object { "<tr><td>$($_.Description)</td><td>$($_.HotFixID)</td><td>$($_.InstalledOn)</td></tr>" } | Out-String)
    </table>

    <h2>User Login Events (Last 7 Days)</h2>
    <table>
        <tr><th>Time</th><th>Message</th></tr>
        $($loginEvents | ForEach-Object { "<tr><td>$($_.TimeCreated)</td><td>$($_.Message)</td></tr>" } | Out-String)
    </table>
</body>
</html>
"@

# Save the report to file
$htmlContent | Out-File -FilePath $reportFile

Write-Host "Complete System Report generated at $reportFile"
