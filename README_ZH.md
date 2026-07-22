# MaidKit

<p align="center">
  <img src="assets/icons/icon-padded.png" width="120" alt="MaidKit Logo">
</p>

<p align="center">
  <b>一款跨平台 SSH 服务器管理器</b>
</p>

<p align="center">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License"></a>
</p>

---

MaidKit 是小羊在给服务器当女仆的时候（维护服务器）用到的工具合集。旨在提供一个非侵入式（100% 基于 SSH，不在服务器上安装任何软件，增加安全风险）更加方便的维护服务器。

基于 Flutter 构建，MaidKit 可在桌面和移动平台上运行。受 [Island](https://github.com/Solsynth/HyperNet.Surface) 项目桌面原生理念的启发，MaidKit 将同样的简洁、实用哲学带到了服务器管理领域。

---

## 目录

- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [架构](#架构)
- [技术栈](#技术栈)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 功能特性

### 服务器管理

| 功能 | 说明 |
|------|------|
| 仪表盘 | 服务器卡片网格，实时显示状态、负载、内存和运行时间 |
| 活动监控 | 实时性能图表（CPU、内存、网络、磁盘） |
| 终端 | 支持分屏、拖拽标签页和命令面板的完整 SSH 终端 |
| 文件管理 | 双窗格 SFTP 浏览器，支持拖拽传输和内置编辑器 |
| 进程管理 | 查看和终止运行中的进程 |
| 服务管理 | Systemd 单元管理（启动/停止/启用/禁用） |
| Web 服务器 | nginx 和 Caddy 配置管理 |
| 定时任务 | 编辑 crontab 计划任务 |
| 软件包 | 软件包管理（apt、dnf 等） |
| 防火墙 | UFW、firewalld、nftables 和 iptables 管理 |
| 端口转发 | 本地和远程隧道配置 |

### 容器管理

- Docker 和 Podman 容器管理
- 启动、停止、重启、暂停、终止和删除容器
- Compose 项目分组
- 容器镜像管理
- 运行时安装辅助

### 项目管理

- 部署项目目录
- 将 Compose 堆栈、Web 服务器和容器分组管理
- 以 TOML 格式导入和导出

### 脚本片段

- 创建和可编辑的可复用 Shell 脚本
- 在一台或多台已连接的服务器上执行
- 流式输出与进度追踪

### 安全

- AES-GCM 256 位加密凭证库
- PBKDF2 密钥派生（310,000 次迭代）
- 生物识别解锁支持
- 加密备份归档（.mkb）

### 设置

- 主题（系统/浅色/深色）
- 语言（English / 简体中文）
- 终端渲染器选择（Ghostty libghostty-vt 或 xterm）
- 启动时自动连接
- 指标刷新间隔
- 数据导出和导入

---

## 快速开始

### 前置条件

- 安装 [Flutter SDK](https://flutter.dev)（SDK ^3.12.2）
- Windows 开发需要安装 [NASM](https://www.nasm.us)（`webcrypto` 原生资源所需）：
  ```powershell
  winget install NASM.NASM
  ```
- Linux 开发需要安装额外依赖：
  ```bash
  sudo apt-get update -y
  sudo apt-get install -y \
    ninja-build \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    keybinder-3.0 \
    libnotify-dev
  ```

### 运行应用

```bash
# 安装依赖
flutter pub get

# 调试模式运行
flutter run

# 构建发布版本
flutter build <platform>
```

### 开发

修改路由注解或 Drift 架构后需要重新生成代码：

```bash
dart run build_runner build
```

提交前运行检查：

```bash
dart format lib test
flutter analyze
flutter test
```

---

## 架构

功能模块扁平化，直接位于 `lib/<feature>/` 下。应用使用：

- **Riverpod** 进行状态管理，使用 `ConsumerWidget` 实现响应式视图
- **auto_route** 实现声明式嵌套导航
- **Drift** 用于本地 SQLite 持久化
- **dartssh2** 用于 SSH 连接
- **island_ui_foundation** 提供桌面窗口框架

完整的架构指南请参见 [docs/architecture.md](./docs/architecture.md)。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| **框架** | Flutter + Material 3 |
| **状态管理** | Riverpod + flutter_hooks |
| **路由** | auto_route |
| **数据库** | Drift (SQLite) |
| **SSH** | dartssh2 |
| **加密** | Cryptography (AES-GCM, PBKDF2) |
| **终端** | libghostty-vt / xterm |
| **桌面** | window_manager + island_ui_foundation |

---

## 贡献

欢迎贡献！请随时提交 Issue 或 Pull Request。

---

## 许可证

本项目基于 GNU Affero General Public License v3.0 (AGPL-3.0) 许可证发布。

如果你部署本软件的实例、分叉本项目，或重新分发本软件的修改版本，你必须遵守 AGPL-3.0 许可证条款，包括：

- 包含原始许可证的副本
- 保留现有的版权声明和署名
- 清楚地说明你所做的任何修改
- 为通过网络与服务交互的用户提供相应的源代码

在适用情况下，必须保留对 LittleSheep、Solsynth 以及本项目贡献者的原始作者身份和版权归属。

请注意，AGPL-3.0 许可证仅适用于软件源代码。某些资产、Logo、图标、品牌材料和商标可能单独许可，不自动受相同条款覆盖。

完整的许可证文本请参见 [LICENSE.txt](./LICENSE.txt)。

---

<p align="center">
  由 LittleSheep + ❤️ 打造
</p>
