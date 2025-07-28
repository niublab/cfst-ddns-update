# Systemd 定时执行 cfst\_ddns.sh

以下说明演示如何使用 Systemd 将 `cfst_ddns.sh` 脚本每 10 分钟自动执行一次。

---

## 1. 安装脚本

1. 将脚本复制到 `/usr/local/bin`：

   ```bash
   sudo cp cfst_ddns.sh /usr/local/bin/
   ```
2. 赋予可执行权限：

   ```bash
   sudo chmod +x /usr/local/bin/cfst_ddns.sh
   ```

---

## 2. 创建 Systemd 服务单元

在 `/etc/systemd/system/` 目录下创建文件 `cfst_ddns.service`：

```ini
[Unit]
Description=Cloudflare DDNS 更新服务
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cfst_ddns.sh
User=root

[Install]
WantedBy=multi-user.target
```

---

## 3. 创建 Systemd 定时器单元

在 `/etc/systemd/system/` 目录下创建文件 `cfst_ddns.timer`：

```ini
[Unit]
Description=每 10 分钟运行一次 Cloudflare DDNS 更新

[Timer]
# 启动后等待 2 分钟首次运行
OnBootSec=2min
# 上一次激活后等待 10 分钟再次运行
OnUnitActiveSec=10min
# 定时精度，可选，默认为 1min
AccuracySec=1min

[Install]
WantedBy=timers.target
```

---

## 4. 启用并启动定时器

执行以下命令：

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用并立即启动定时器
sudo systemctl enable --now cfst_ddns.timer
```

---

## 5. 查看定时器状态

```bash
# 列出定时器及下次触发时间
systemctl list-timers cfst_ddns.timer
```

以上即完成了使用 Systemd 定时执行 `cfst_ddns.sh` 的配置。
