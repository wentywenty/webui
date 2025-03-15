# 项目环境设置脚本

# 版本和配置
$pythonVersion = "3.11"
$projectName = "WebUI"

# 颜色定义
function Write-ColorText {
    param (
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

# 显示欢迎信息
Write-ColorText "`n欢迎使用 $projectName 项目环境配置工具" "Cyan"
Write-ColorText "=================================" "Cyan"

# 检查 Python 是否已安装
Write-ColorText "`n[1/7] 检查 Python..." "Yellow"
try {
    $pythonInfo = python --version 2>&1
    if ($pythonInfo -match "Python (\d+\.\d+)\.\d+") {
        $currentVersion = $Matches[1]
        Write-ColorText "已找到 Python $currentVersion" "Green"
        
        if ([double]$currentVersion -lt [double]$pythonVersion) {
            Write-ColorText "警告: 建议使用 Python $pythonVersion 或更高版本" "Yellow"
        }
    }
    else {
        throw "无法确定 Python 版本"
    }
}
catch {
    Write-ColorText "未找到 Python。请先安装 Python $pythonVersion 或更高版本。" "Red"
    Write-Host "下载地址: https://www.python.org/downloads/"
    exit 1
}

# 检查包管理工具
Write-ColorText "`n[2/7] 检查包管理工具..." "Yellow"
$packageManager = $null

# 检查 uv
try {
    $uvVersion = uv --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "已找到 uv: $uvVersion" "Green"
        $packageManager = "uv"
    }
}
catch {
    Write-ColorText "未找到 uv，将尝试其他包管理工具" "Yellow"
}

# 如果没有 uv，检查 pip
if (-not $packageManager) {
    try {
        $pipVersion = pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "已找到 pip: $pipVersion" "Green"
            $packageManager = "pip"
        }
        else {
            throw "pip 命令返回错误"
        }
    }
    catch {
        Write-ColorText "未找到可用的 Python 包管理工具。请确保 pip 已安装。" "Red"
        exit 1
    }
}

# 检查 zip 命令
Write-ColorText "`n[3/7] 检查 zip 工具..." "Yellow"
try {
    $zipOutput = zip --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $zipVersion = ($zipOutput -split "`n")[0]
        Write-ColorText "已找到 zip: $zipVersion" "Green"
    }
    else {
        throw "zip 命令返回错误"
    }
}
catch {
    Write-ColorText "未找到 zip 命令。打包功能需要此工具。" "Red"
    Write-Host "Windows 用户可以使用以下方式安装 zip:"
    Write-Host "1. 安装 Git Bash (包含 zip 命令)"
    Write-Host "2. 或通过 Scoop 安装: scoop install zip"
    Write-Host "3. 或通过 Chocolatey 安装: choco install zip"
}

# 检查 GitHub CLI
Write-ColorText "`n[4/7] 检查 GitHub CLI..." "Yellow"
$ghInstalled = $false

try {
    $ghVersion = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "已找到 GitHub CLI: $ghVersion" "Green"
        $ghInstalled = $true
        
        # 检查 GitHub CLI 登录状态
        $status = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "GitHub CLI 已登录" "Green"
        }
        else {
            Write-ColorText "GitHub CLI 未登录。如需发布模块，请运行 'gh auth login' 进行登录。" "Yellow"
        }
    }
    else {
        throw "gh 命令返回错误"
    }
}
catch {
    Write-ColorText "未找到 GitHub CLI。发布功能需要此工具。" "Yellow"
    Write-Host "下载地址: https://cli.github.com/"
}

# 检查 Scoop (可选)
Write-ColorText "`n[5/7] 检查 Scoop..." "Yellow"
try {
    $scoopInfo = scoop --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "已找到 Scoop: $scoopInfo" "Green"
    }
    else {
        throw "scoop 命令返回错误"
    }
}
catch {
    Write-ColorText "未找到 Scoop。这是可选的，但推荐安装以便于管理工具。" "Yellow"
    Write-Host "安装指南: https://scoop.sh/"
}

# 创建目录结构
Write-ColorText "`n[6/7] 创建项目目录结构..." "Yellow"

# 创建 release 目录
if (!(Test-Path ".\release")) {
    New-Item -ItemType Directory -Path ".\release" | Out-Null
    Write-ColorText "创建了 release 目录" "Green"
}
else {
    Write-ColorText "release 目录已存在" "Green"
}

# 创建 debug 目录
if (!(Test-Path ".\debug")) {
    New-Item -ItemType Directory -Path ".\debug" | Out-Null
    Write-ColorText "创建了 debug 目录" "Green"
}
else {
    Write-ColorText "debug 目录已存在" "Green"
}

# 检查 webroot 目录
if (!(Test-Path ".\webroot")) {
    New-Item -ItemType Directory -Path ".\webroot" | Out-Null
    Write-ColorText "创建了 webroot 目录 (注: 这是模块的 Web 根目录)" "Green"
}
else {
    Write-ColorText "webroot 目录已存在" "Green"
    if (!(Test-Path ".\webroot\index.html")) {
        Write-ColorText "警告: webroot 目录中没有 index.html 文件" "Yellow"
    }
}

# 创建虚拟环境
Write-ColorText "`n[7/7] 设置 Python 虚拟环境..." "Yellow"
$venvExists = Test-Path ".\.venv"

if (!$venvExists) {
    Write-Host "创建新的虚拟环境..."
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) {
        Write-ColorText "创建虚拟环境失败！" "Red"
        exit 1
    }
    Write-ColorText "虚拟环境已创建" "Green"
}
else {
    Write-ColorText "虚拟环境已存在" "Green"
}

# 激活虚拟环境
try {
    Write-Host "激活虚拟环境..."
    . .\.venv\Scripts\Activate.ps1
    if ($?) {
        Write-ColorText "虚拟环境已激活" "Green"
    }
    else {
        throw "无法激活虚拟环境"
    }
}
catch {
    Write-ColorText "激活虚拟环境失败: $_" "Red"
    exit 1
}

# 完成
Write-ColorText "`n环境设置完成！" "Cyan"
Write-ColorText "=================================" "Cyan"
Write-Host "您现在可以:"
Write-Host "- 运行 'python zip.py' 打包 debug 版本模块"
Write-Host "- 运行 'python zip.py release' 打包 release 版本模块"
if ($ghInstalled) {
    Write-Host "- 打包后运行 '.\publish.ps1' 发布模块到 GitHub"
}
Write-Host "- 编辑 'webroot' 目录中的文件"
Write-Host ""
Write-Host "输入 'deactivate' 以退出虚拟环境"
Write-Host ""
Write-Host "祝您使用愉快！"

# # 安装/更新依赖
# Write-Host "安装必要的依赖..."
# if ($packageManager -eq "uv") {
#     uv pip install -U pip setuptools wheel
#     uv pip install -U zipfile36
# }
# else {
#     python -m pip install -U pip setuptools wheel
#     python -m pip install -U zipfile36
# }
