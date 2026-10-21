# 迁移草案：直接基于官方 `php` 镜像构建（official-php base）

> 状态：**草案（未接入 CI，未替换现有模板）**
> 触发背景：CVE-2026-109618 / CVE-2026-109619（2026-10-21）应急响应中，
> 修复链条 `php.net → docker-library(Jenkins) → serversideup(手动触发) → 我们`
> 的中间环节造成数小时空窗。本草案砍掉中间两层。

## 目标

- `Dockerfile.official.template` + `base/` 目录替代 `serversideup/php` 基座
- php.net 发版后只需等 Docker 官方 library 构建完成即可自行重建
- 支持钉 patch 版本 tag（如 `8.4.27-fpm-alpine3.24`），重建时机完全自控
- **兼容承诺**：`install/` 下现有脚本（06/60/61/62/63/65）、Dockerfile ENV 契约、
  冒烟测试全部不动

## 架构对比

| 层 | 现状（serversideup 基座） | 草案（官方基座） |
|---|---|---|
| PHP 运行时 | serversideup/php（=官方 PHP + 其运行时） | `php:${BASE_TAG}` 官方镜像 |
| 进程管理 | s6-overlay（上游安装） | s6-overlay v3.2.3.2（构建时拉取，钉版本） |
| entrypoint 编排 | 上游 `docker-php-serversideup-entrypoint` + 把 entrypoint.d 转换成 s6 oneshot 的机制 | 自有 `dsf-entrypoint`：entrypoint.d 全部跑完（失败即中止）再 `exec /init`，顺序保证更简单 |
| php.ini / pool 模板 | 上游模板（`${VAR}` 占位符） | **原样 vendored**（同路径同占位符，加署名头） |
| nginx | nginx.org 源、钉版本 | 发行版包（Alpine apk / Debian apt） |
| nginx 主配置 | 上游 `nginx.conf.template` envsubst | 自有极简模板 `base/etc/nginx/nginx.conf.template` + `07-render-nginx-conf.sh` |

## 文件清单

### 新增

- `Dockerfile.official.template` — 单一模板，`ARG VARIANT=alpine|debian` 分支处理包管理
- `base/usr/local/bin/dsf-entrypoint` — entrypoint.d 执行器（替代上游同名机制）
- `base/etc/entrypoint.d/05-fpm-pool-user.sh` — 等价上游 `5-fpm-pool-user.sh`
- `base/etc/entrypoint.d/07-render-nginx-conf.sh` — nginx.conf envsubst（上游 `10-init-webserver-config.sh` 的我们所需子集）
- `base/etc/s6-overlay/s6-rc.d/{php-fpm,nginx}/` — longrun 服务（run/type/notification-fd/data/check）
- `base/etc/s6-overlay/user-bundles.d/user/contents.d/{php-fpm,nginx}` — 静态注册（对齐 60-s6-register.sh 探测的"新 base"路径）
- `base/etc/nginx/nginx.conf.template` — 极简主配置，仅含我们需要的指令
- `base/usr/local/etc/php/conf.d/serversideup-docker-php.ini`、`base/usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf` — **自研模板**：生效指令与原 serversideup 版逐行一致（已 diff 验证；仅省略无指令的空 section 头），占位符名/路径不变，06-compat.sh 零改动。**无 GPL 内容**（默认值来自 PHP 官方 php.ini，PHP License 宽松）

### 构建期要点（与 serversideup 基座的差异）

- **官方 php 基座自带扩展远少于 serversideup**（sodium/opcache 内置，其余要装）：在 serversideup 基座白嫖的 `redis / zip / pdo_mysql / pdo_pgsql` 需显式安装，构建内有 19 项扩展的完整校验
- **官方 php 基座的默认 fpm pool（`php-fpm.d/www.conf`）必须清除**（serversideup 同样这么做）：否则默认 `[www]` pool 抢先生效，`PHP_FPM_CHILD_PROCESS_USER` 被静默忽略
- **7 个 PECL 扩展改为 GitHub 钉版本源码安装**（apcu/igbinary/msgpack/memcached/imagick/yaml/redis）：pecl.php.net 的 tarball CDN 在 CVE-2026-109618/109619 发布日全球 504 数小时，GitHub 源消除该单点；版本号与 pecl latest-stable 逐一核对（经 pecl REST API）。注意 **phpredis 的 liblzf 是 git submodule**（GitHub 压缩包不含子模块内容，pecl 校验直接失败），redis 需先合并子模块树再交给 install-php-extensions 本地目录安装
- nginx 用发行版包（Alpine apk / Debian apt），不再走 nginx.org 源

### 复用（零改动）

- `install/` 全部（06-compat、60-s6-register、61-drupal、62-cron、63-sshd、65-logrotate、cron/sshd s6 服务、nginx Drupal 站点配置、drush.yml、sshd 配置、PS1 等）
- `scripts/test-local-build.sh` 冒烟流程（构建参数名不同，需加 `--build-arg BASE_TAG`）

## 兼容性契约（保持不变）

- **ENV 契约**：现有 Dockerfile 中全部 ENV 原样保留；补充上游模板渲染所需的默认值（`PHP_FPM_POOL_NAME`、`NGINX_FASTCGI_BUFFERS`、`PHP_SESSION_COOKIE_*` 等），与现镜像行为一致
- **canonical 变量**：`PHP_FPM_PROCESS_MANAGER` 等 nfrastack 时代变量仍由 06-compat.sh 渲染进 pool 模板
- **路径契约**：pool/php.ini 模板路径不变；`/etc/s6-overlay/user-bundles.d/user/contents.d/` 不变（60-s6-register.sh 探测逻辑直接命中"新 base"分支）
- **进程身份**：nginx worker / php-fpm 子进程仍为 `nginx(80):www-data`（Alpine 82 / Debian 33）；Debian 发行版 nginx 无 `nginx` 用户，由 Dockerfile 创建
- **php.ini `${VAR}` 运行时展开**：这是 PHP 自身特性（php-fpm pool 及 PHP ini 的环境变量展开），与基座无关，行为不变

## entrypoint 顺序（新）

```
05-fpm-pool-user.sh     (新增，等价上游 5)
06-compat.sh            (不变)
07-render-nginx-conf.sh (新增，envsubst nginx.conf；在 06 之后因 06 要改模板里的 worker_processes)
60-s6-register.sh       (不变)
61-drupal.sh            (不变，编辑已渲染的 nginx.conf + conf.d)
62/63/65                (不变)
→ exec /init（s6 启动 php-fpm、nginx、cron、sshd）
```

对比现状少了上游 0/1/5-generate-ssl/10/50 五个脚本：0/1 是纯信息输出，50 是 Laravel 专用，
5-generate-ssl 仅 SSL_MODE≠off 时用（本镜像 Drupal 场景未使用；如未来需要可单独补回）。

## CI 接入方案（草案验证通过后）

- 新 workflow（或现有 workflow 加 `file` 矩阵项）构建 `Dockerfile.official.template`，
  tag 建议加后缀区分期，如 `8.4-alpine-official`，验证稳定后再切换正式 tag
- 版本矩阵改为 `BASE_TAG` 列表：`8.3/8.4/8.5 × fpm-alpine3.24 / fpm-bookworm`
- 紧急场景：直接钉 `8.4.27-fpm-alpine3.24` 这类 patch tag 触发构建

## 验证计划

1. `docker build -f Dockerfile.official.template --build-arg BASE_TAG=8.4-fpm-alpine3.24 --build-arg PHP_VERSION=8.4 -t test:8.4-alpine .`
2. Debian 变体同上（`8.4-fpm-bookworm`、`VARIANT=debian`）
3. 冒烟：挂载 Drupal 代码 + `DRUPAL_WEB_ROOT=web`，验证安装页 200、`php -v`、扩展清单、
   进程身份（`ps` 查看 nginx/php-fpm 用户）、SSH 登录、cron 注册
4. 与现镜像 diff 关键行为：响应头、phpinfo 中的 ini 生效值、pool 参数（`PHP_FPM_MAX_CHILDREN` 等）

## 风险与取舍

| 风险 | 说明 | 缓解 |
|---|---|---|
| 失去 serversideup 周更跟随 | OS 层安全补丁以前跟着上游镜像周更走，之后靠自己 | CI 保留每周定时重建（现已有 Sunday cron）；可配 Renovate/定时检查 base tag digest |
| nginx 版本不再钉死 | 发行版 nginx 随 OS 仓库滚动 | 如需钉版本，可后续换回 nginx.org 源（serversideup 的做法，构建复杂度+） |
| s6-overlay / install-php-extensions 版本维护 | 两个外部组件要自己跟进升级 | 已做 build ARG 钉版本；升级是改一个默认值的事 |
| ~~GPL vendored 文件~~（已闭环：自研模板替代，零 GPL 内容） | — | — |
| 与上游 5.x 演进脱钩 | 上游未来新特性（如配置框架变更）不再自动获得 | 本就是目的之一；我们需要的特性已 vendored |

## 决策（2026-10-21 已定）

1. **发行策略**：先并行发 `-official` tag（如 `8.4-alpine-official`）观察验证，稳定后再切换正式 tag
2. **模板版权**：~~vendored GPL~~ → **自研模板**（生效指令 diff 验证与原行为一致，仓库零 GPL 文件；分析依据：原模板生效行 = PHP 官方默认值 + 占位符，无 serversideup 独创表达）
3. **Debian nginx**：**不用 nginx 镜像多阶段构建**——nginx 二进制动态链接 pcre2/zlib/openssl/libc，跨镜像 COPY 需同步搬运 .so 且 SONAME 必须匹配（Alpine musl 与 Debian glibc 不可混用），脆弱且省不了多少；默认发行版包，未来若需钉版本则复刻 serversideup 的 nginx.org 源方案
4. **旧模板（serversideup 基座）**：保留 **3 个月以上**作回退

## 决策点（历史，已闭环）

~~1. 替换时机 / 2. GPL vendored 模板 / 3. Debian 变体的 nginx / 4. 旧模板保留多久~~ → 见上方"决策"
