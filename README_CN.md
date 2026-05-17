# chinagfw.com/repo 镜像：sing-box

## 一键安装

```sh
bash <(curl -Ls https://chinagfw.com/repo/install.sh)
```

## 目录结构（镜像端）

默认部署到服务器：

`/opt/chinagfw/repo/`

并同步到 nginx 静态目录：

`/var/www/html/repo/`

```
/opt/chinagfw/repo/
├── sing-box/
├── sing-box.tar.gz
├── sing-box.sh
├── geoip.db
├── geosite.db
├── release/
└── backup/
```

## 部署方式（镜像维护者）

1. 配置变量：复制 `.env.example` 为 `.env` 并按需修改
2. 同步官方并部署：

```sh
./sync.sh
```

或仅重新打包并上传：

```sh
./deploy.sh
```

## 更新方式

- `sync.sh` 会执行：
  - `git fetch upstream`
  - `git merge --ff-only upstream/main`
  - 重新打包 `sing-box.tar.gz`
  - 上传到 `SERVER_PATH`
  - 备份旧 tar 包到 `/opt/chinagfw/repo/backup/`

## 镜像说明与 fallback

`sing-box.sh` 已调整为镜像优先下载策略：

1. `https://chinagfw.com/repo/`（主镜像）
2. `https://ghproxy.com/`（公共代理）
3. GitHub 原站（raw/github/release）

所有关键下载都包含超时重试与自动切换。

## 国内服务器使用建议

- 优先使用 `install.sh` 一键安装入口
- 如遇 GitHub 访问异常，会自动切换到 ghproxy 或直连

