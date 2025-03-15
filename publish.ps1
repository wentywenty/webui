# 确认发布类型
function Confirm-ReleaseType {
    Write-Host "`n使用哪个构建类型进行发布?" -ForegroundColor Cyan
    Write-Host "1. release 构建版本 (推荐)"
    Write-Host "2. debug 构建版本"
    
    $choice = Read-Host "请选择 [1-2]，默认为 1"
    
    if ($choice -eq "2") {
        return "debug"
    }
    return "release"
}

# 从信息文件读取模块信息
function Get-ModuleInfo {
    param (
        [string]$BuildType = "release"
    )
    
    $infoFiles = Get-ChildItem -Path ".\$BuildType\" -Filter "*-info.txt" | Sort-Object LastWriteTime -Descending
    
    if ($infoFiles.Count -eq 0) {
        Write-Error "在 $BuildType 目录中找不到模块信息文件。请先运行 `"python zip.py $BuildType`" 打包模块。"
        return $null
    }
    
    $infoPath = $infoFiles[0].FullName
    Write-Host "使用信息文件: $infoPath"
    
    $moduleInfo = @{}
    $lines = Get-Content $infoPath -Encoding UTF8
    
    # 跳过前几行（构建类型和时间信息）
    $capturingInfo = $false
    foreach ($line in $lines) {
        if ($line -match "^模块信息:") {
            $capturingInfo = $true
            continue
        }
        
        if ($capturingInfo -and $line -match "=") {
            $key, $value = $line -split '=', 2
            $moduleInfo[$key] = $value
        }
    }
    
    return $moduleInfo
}

# 查找最新的 ZIP 文件
function Get-LatestZipFile {
    param (
        [string]$BuildType = "release",
        [hashtable]$ModuleInfo
    )
    
    $moduleNamePattern = $ModuleInfo.name
    $moduleVersionPattern = $ModuleInfo.version
    $moduleVersionCodePattern = $ModuleInfo.versionCode
    
    # 查找格式为 "模块名称-模块版本-模块版本号-release.zip" 的文件
    $zipPattern = "$moduleNamePattern-$moduleVersionPattern-$moduleVersionCodePattern-$BuildType.zip"
    Write-Host "查找匹配的 ZIP 文件: $zipPattern"
    
    $zipFiles = Get-ChildItem -Path ".\$BuildType\" -Filter $zipPattern | Sort-Object LastWriteTime -Descending
    
    if ($zipFiles.Count -eq 0) {
        Write-Error "在 $BuildType 目录中找不到匹配的 ZIP 文件。请先运行 `"python zip.py $BuildType`" 打包模块。"
        return $null
    }
    
    return $zipFiles[0].FullName
}

# 创建 GitHub Release
function Create-GitHubRelease {
    param (
        [string]$ZipFile,
        [hashtable]$ModuleInfo,
        [string]$BuildType = "release"
    )

    $version = $ModuleInfo.version
    $tag = "v$($version -replace 'v', '')"
    $title = "$($ModuleInfo.name) $tag"
    $notes = $ModuleInfo.description
    
    if ($BuildType -eq "debug") {
        $title = "$title (Debug)"
        $notes = "[DEBUG 版本] $notes`n`n此为调试版本，不建议一般用户使用。"
    }

    Write-Host "创建 GitHub Release: $tag"
    Write-Host "标题: $title"
    Write-Host "描述: $notes"
    Write-Host "文件: $ZipFile"
    
    $confirmation = Read-Host "确认发布? (Y/N)"
    if ($confirmation -ne "Y" -and $confirmation -ne "y") {
        Write-Host "已取消发布操作。"
        return $false
    }

    gh release create $tag $ZipFile --title $title --notes $notes
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "创建 GitHub Release 失败。"
        return $false
    }
    
    Write-Host "GitHub Release 创建成功! 标签: $tag" -ForegroundColor Green
    return $true
}

# 主脚本逻辑
Write-Host "=== KernelSU 模块发布工具 ===" -ForegroundColor Cyan

# 检查是否可以访问 GitHub CLI
try {
    $null = gh --version
} catch {
    Write-Error "无法访问 GitHub CLI。请先安装 GitHub CLI 并运行 'gh auth login' 登录。"
    exit 1
}

$buildType = Confirm-ReleaseType

$moduleInfo = Get-ModuleInfo -BuildType $buildType
if ($null -eq $moduleInfo) {
    exit 1
}

Write-Host "`n模块信息:" -ForegroundColor Cyan
Write-Host "ID: $($moduleInfo.id)"
Write-Host "名称: $($moduleInfo.name)"
Write-Host "版本: $($moduleInfo.version)"
Write-Host "版本号: $($moduleInfo.versionCode)"
Write-Host "作者: $($moduleInfo.author)"
Write-Host "描述: $($moduleInfo.description)"

$zipFile = Get-LatestZipFile -BuildType $buildType -ModuleInfo $moduleInfo
if ($null -eq $zipFile) {
    exit 1
}

Write-Host "`n找到 ZIP 文件: $zipFile" -ForegroundColor Green

if (Create-GitHubRelease -ZipFile $zipFile -ModuleInfo $moduleInfo -BuildType $buildType) {
    Write-Host "`n发布操作已完成!" -ForegroundColor Cyan
} else {
    Write-Error "`n发布操作失败。"
    exit 1
}