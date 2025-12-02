# DisableSogouNetwork
# 新脚本核心特性介绍
# 新脚本核心特性介绍
此脚本基于 [yongxin/DisableSogouNetwork](https://github.com/yongxin-ms/DisableSogouNetwork/tree/master) 项目进行二次开发，主要新增功能包括：

## ✨ 主要功能亮点

### 🔍 智能安装检测
- **自动定位搜狗安装路径** - 无需人工干预确认
- **多实例环境支持** - 智能识别多个安装版本
- **注册表防护机制** - 自动建立代理设置保护屏障

### 🛡️ 网络访问控制
- **代理检测屏蔽** - 有效防止搜狗输入法绕过Clash代理
- **网络隔离加固** - 彻底阻断未经授权的网络连接

### 📊 操作体验优化
- **实时进度反馈** - 清晰展示检测流程与执行状态
- **详细结果报告** - 完整输出操作日志与处理结果
- **用户交互简化** - 自动化流程减少手动配置


### !!! 若执行时发现报错，大概率是权限的问题，需要进行以下的操作：
# 1. 查看当前执行策略
Get-ExecutionPolicy

# 2. 如果是 Restricted，需要更改
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# 3. 然后再次尝试运行
.\run.ps1
