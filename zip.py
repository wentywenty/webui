import os
import sys
import shutil
import subprocess
import tempfile
import configparser
import time

def read_module_prop():
    """读取 module.prop 文件获取所有模块信息"""
    props = {}
    
    # 读取文件内容
    with open('module.prop', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 解析每一行
    for line in content.splitlines():
        if '=' in line and not line.strip().startswith('#'):
            key, value = line.split('=', 1)
            props[key.strip()] = value.strip()
    
    # 确保必要的属性存在
    required_props = ['id', 'name', 'version', 'versionCode', 'author', 'description']
    for prop in required_props:
        if prop not in props:
            props[prop] = ''
            print(f"警告: module.prop 中缺少 {prop} 属性")
    
    return props

def create_module_zip(module_info, build_type='debug'):
    """创建模块的 ZIP 文件
    
    Args:
        module_info: 包含模块信息的字典
        build_type: 构建类型，'debug' 或 'release'
    
    Returns:
        生成的 ZIP 文件路径
    """
    module_id = module_info['id']
    module_name = module_info['name']
    module_version = module_info['version']
    module_version_code = module_info['versionCode']
    
    # 创建 debug 或 release 目录
    build_dir = os.path.join(os.getcwd(), build_type)
    if not os.path.exists(build_dir):
        os.makedirs(build_dir)
    
    # 构建文件名: 模块名称-模块版本-模块版本号-debug/release.zip
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    zip_filename = os.path.join(
        build_dir, 
        f"{module_name}-{module_version}-{module_version_code}-{build_type}.zip"
    )
    
    # 创建临时目录
    temp_dir = tempfile.mkdtemp()
    module_dir = os.path.join(temp_dir, module_id)
    webroot_dir = os.path.join(module_dir, 'webroot')
    
    # 创建目录结构
    os.makedirs(module_dir)
    os.makedirs(webroot_dir)
    
    # 复制文件
    print(f"复制文件到临时目录: {temp_dir}")
    
    # 复制 module.prop
    shutil.copy('module.prop', os.path.join(module_dir, 'module.prop'))
    shutil.copy('customize.sh', os.path.join(module_dir, 'customize.sh'))
    shutil.copy('service.sh', os.path.join(module_dir, 'service.sh'))
    shutil.copy('update.json', os.path.join(module_dir, 'update.json'))
    
    # 复制 README.md (如果存在)
    if os.path.exists('README.md'):
        shutil.copy('README.md', os.path.join(module_dir, 'README.md'))
    
    # 复制 webroot 目录内容
    if os.path.exists('webroot'):
        for item in os.listdir('webroot'):
            source = os.path.join('webroot', item)
            dest = os.path.join(webroot_dir, item)
            if os.path.isdir(source):
                shutil.copytree(source, dest)
            else:
                shutil.copy2(source, dest)
    
    # 为 debug 版本添加调试信息
    if build_type == 'debug':
        # 创建 debug 标记文件
        with open(os.path.join(module_dir, '.debug'), 'w') as f:
            f.write(f"Debug build created at {timestamp}\n")
        
        # 添加更详细的日志输出设置
        if os.path.exists(os.path.join(module_dir, 'service.sh')):
            with open(os.path.join(module_dir, 'service.sh'), 'a') as f:
                f.write('\n# 调试输出\nset -x\n')
    
    # 创建 zip 文件
    print(f"创建 {build_type.upper()} ZIP 文件: {zip_filename}")
    current_dir = os.getcwd()
    os.chdir(temp_dir)
    subprocess.run(['zip', '-r', zip_filename, module_id], check=True)
    os.chdir(current_dir)
    
    print(f"ZIP 文件已创建: {zip_filename}")
    
    # 写入模块信息到文本文件
    info_file = os.path.join(build_dir, f"{module_name}-{module_version}-info.txt")
    with open(info_file, "w", encoding="utf-8") as f:
        f.write(f"构建类型: {build_type.upper()}\n")
        f.write(f"构建时间: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("模块信息:\n")
        for key, value in module_info.items():
            f.write(f"{key}={value}\n")
    
    # 清理临时目录
    print("清理临时目录...")
    shutil.rmtree(temp_dir)
    
    return zip_filename

def main():
    """主函数"""
    # 确定构建类型 (debug 或 release)
    build_type = 'debug'  # 默认为 debug
    if len(sys.argv) > 1 and sys.argv[1].lower() == 'release':
        build_type = 'release'
    
    print(f"开始 {build_type.upper()} 构建...")
    
    # 读取模块信息
    module_info = read_module_prop()
    print(f"模块信息: ID={module_info['id']}, 名称={module_info['name']}, 版本={module_info['version']}, 版本号={module_info['versionCode']}")
    
    # 创建 ZIP 文件
    zip_filename = create_module_zip(module_info, build_type)
    
    print(f"{build_type.upper()} 打包操作已完成! ZIP 文件已保存在 {build_type} 目录中。")
    
    if build_type == 'release':
        print("提示: 如需发布 GitHub Release，请运行 publish.ps1 脚本。")

if __name__ == "__main__":
    main()