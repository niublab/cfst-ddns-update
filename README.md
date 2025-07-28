# cfst-ddns-update
cfst优选后自动更新DNS记录

脚本，用于：

* 使用 CloudflareSpeedTest (`cfst`) 进行网络测速
* 提取最佳测试 IP
* 自动更新 Cloudflare DNS A/AAAA 记录
* 支持通过 Systemd 定时执行

---

## 目录结构

```bash
cfst-ddns/
├── cfst_ddns.sh       # 主脚本
├── systemd.md         # Systemd 定时服务和定时器配置说明
├── README.md          # 本文件
└── LICENSE            # 开源许可（可根据需求添加）
```

---

## 前提条件

1. Linux 系统（推荐 Debian/Ubuntu）
2. 已安装以下依赖：

   * `curl`
   * `jq`
3. 拥有 Cloudflare API Token，具备 Zone.DNS 编辑权限
4. DNS Zone ID 和要更新的记录名称

---

## 安装与配置

1. 克隆或下载本仓库：

   ```bash
   git clone https://github.com/your-repo/cfst-ddns-deploy.git
   cd cfst-ddns-deploy
   ```
2. 编辑脚本，填写 Cloudflare 信息：

   ```bash
   vim cfst_ddns.sh
   # 设置 CF_API_TOKEN、CF_ZONE_ID、DNS_NAME、RECORD_TYPE
   ```
3. 赋予执行权限：

   ```bash
   chmod +x cfst_ddns.sh
   ```

---

## 手动运行

* 查看帮助：

  ```bash
  ./cfst_ddns.sh --help
  ```
* 下载并安装最新 `cfst`：

  ```bash
  ./cfst_ddns.sh --dl
  ```
* 执行测速并更新 DNS：

  ```bash
  ./cfst_ddns.sh
  ```

---

## Systemd 定时执行

详见 `systemd.md`，快速部署：

```bash
# 复制脚本并授权
sudo cp cfst_ddns.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/cfst_ddns.sh

# 创建服务单元和定时器
sudo cp systemd.md /etc/systemd/system/cfst_ddns.service
sudo cp systemd.md /etc/systemd/system/cfst_ddns.timer

# 重新加载并启用定时器\sudo systemctl daemon-reload
sudo systemctl enable --now cfst_ddns.timer
```

---

## 日志

执行过程中会在脚本所在目录生成 `update.log`，记录每次运行的时间戳和操作详情。

---

## 许可协议

本项目禁止商用， 详见 [LICENSE](LICENSE)。

---

## 联系与贡献

如有问题或建议，请提交 Issue 或 Pull Request！

