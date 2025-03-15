import os
import shutil
import subprocess
import sys
import tempfile
import configparser

def read_module_prop():
    """读取 module.prop 文件获取模块信息"""
    config = configparser.ConfigParser()
    # 添加一个虚拟的节点以符合 configparser 格式要求
    with open('module.prop', 'r', encoding='utf-8') as f:
        content = '[dummy]\n' + f.read()
    
    config.read_string(content)
    
    module_id = config['dummy']['id']
    module_name = config['dummy']['name']
    module_version = config['dummy']['version']
    module_author = config['dummy']['author']
    module_description = config['dummy']['description']
    
    return {
        'id': module_id,
        'name': module_name,
        'version': module_version,
        'author': module_author,
        'description': module_description
    }

def check_tools():
    """检查必要的工具是否已安装"""
    # 检查 zip 命令
    try:
        subprocess.run(['zip', '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except FileNotFoundError:
        print("错误: 未找到 'zip' 命令，请先安装")
        return False
    
    # 检查 gh 命令
    try:
        subprocess.run(['gh', '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except FileNotFoundError:
        print("错误: 未找到 GitHub CLI (gh)，请先安装")
        return False
    
    # 检查 gh 是否已登录
    result = subprocess.run(['gh', 'auth', 'status'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        print("错误: GitHub CLI 未登录，请运行 'gh auth login' 登录")
        return False
    
    return True

def create_module_zip(module_info):
    """创建模块的 ZIP 文件"""
    module_id = module_info['id']
    module_version = module_info['version']
    
    # 创建 releases 目录
    releases_dir = os.path.join(os.getcwd(), 'releases')
    if not os.path.exists(releases_dir):
        os.makedirs(releases_dir)
    
    zip_filename = os.path.join(releases_dir, f"{module_id}-{module_version}.zip")
    
    # 创建临时目录
    temp_dir = tempfile.mkdtemp()
    module_dir = os.path.join(temp_dir, module_id)
    webroot_dir = os.path.join(module_dir, 'webroot')
    
    try:
        # 创建目录结构
        os.makedirs(module_dir)
        os.makedirs(webroot_dir)
        
        # 复制文件
        print(f"复制文件到临时目录: {temp_dir}")
        shutil.copy('module.prop', os.path.join(module_dir, 'module.prop'))
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
        
        # 创建 zip 文件
        print(f"创建 ZIP 文件: {zip_filename}")
        current_dir = os.getcwd()
        os.chdir(temp_dir)
        subprocess.run(['zip', '-r', zip_filename, module_id], check=True)
        os.chdir(current_dir)
        
        return zip_filename
    
    except Exception as e:
        print(f"错误: 创建 ZIP 文件失败 - {str(e)}")
        return None
    
    finally:
        # 清理临时目录
        print("清理临时目录...")
        shutil.rmtree(temp_dir)

def create_github_release(module_info, zip_filename):
    """创建 GitHub Release"""
    module_version = module_info['version']
    tag = f"v{module_version.replace('v', '')}"  # 确保版本号格式正确
    title = f"{module_info['name']} {tag}"
    notes = module_info['description']
    
    print(f"创建 GitHub Release: {tag}")
    
    cmd = ['gh', 'release', 'create', tag, zip_filename, '--title', title, '--notes', notes]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    if result.returncode != 0:
        print(f"错误: 创建 GitHub Release 失败 - {result.stderr.decode('utf-8')}")
        return False
    
    print(f"Release 创建成功! 标签: {tag}")
    return True

def main():
    """主函数"""
    # 检查必要工具
    if not check_tools():
        sys.exit(1)
    
    # 读取模块信息
    try:
        module_info = read_module_prop()
        print(f"模块信息: ID={module_info['id']}, 名称={module_info['name']}, 版本={module_info['version']}")
    except Exception as e:
        print(f"错误: 读取 module.prop 文件失败 - {str(e)}")
        sys.exit(1)
    
    # 创建 ZIP 文件
    zip_filename = create_module_zip(module_info)
    if not zip_filename:
        sys.exit(1)
    
    # 创建 GitHub Release
    if not create_github_release(module_info, zip_filename):
        sys.exit(1)
    
    print("所有操作已完成!")

if __name__ == "__main__":
    main()